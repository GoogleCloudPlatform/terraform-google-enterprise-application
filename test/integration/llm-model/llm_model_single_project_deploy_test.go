// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package llm_model

import (
	"errors"
	"fmt"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/git"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/stretchr/testify/assert"

	"os"

	cp "github.com/otiai10/copy"
)

func TestSourceLLMModelSingleProject(t *testing.T) {
	gitLabPath := "../../setup/harness/gitlab"
	gitLab := tft.NewTFBlueprintTest(t, tft.WithTFDir(gitLabPath))
	gitUrl := gitLab.GetStringOutput("gitlab_url")
	gitlabPersonalTokenSecretName := gitLab.GetStringOutput("gitlab_pat_secret_name")
	gitlabSecretProject := gitLab.GetStringOutput("gitlab_secret_project")
	token, err := testutils.GetSecretFromSecretManager(t, gitlabPersonalTokenSecretName, gitlabSecretProject)
	if err != nil {
		t.Fatal(err)
	}

	hostNameWithPath := strings.Split(gitUrl, "https://")[1]
	authenticatedUrl := fmt.Sprintf("https://oauth2:%s@%s/root", token, hostNameWithPath)
	infraSingleProject := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../examples/llm-model/standalone-single-project"))
	projectID := infraSingleProject.GetJsonOutput("cluster_project_id").String()
	region := infraSingleProject.GetJsonOutput("cluster_regions").Array()[0].String()
	appName := "llm-model"
	serviceName := "llamma-model"
	appSourcePath := fmt.Sprintf("../../../examples/%s/6-appsource/", appName)
	deployTargets := infraSingleProject.GetJsonOutput("clouddeploy_targets_names")

	t.Run("replace-repo-contents-and-push", func(t *testing.T) {

		repoName := fmt.Sprintf("eab-%s-%s", appName, serviceName)

		appRepo := fmt.Sprintf("%s/%s", authenticatedUrl, repoName)

		tmpDirApp := t.TempDir()

		vars := map[string]interface{}{
			"project_id": projectID,
			"region":     region,
		}

		appsource := tft.NewTFBlueprintTest(t,
			tft.WithTFDir(appSourcePath),
			tft.WithVars(vars),
			tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		)

		appsource.DefineVerify(func(assert *assert.Assertions) {

			// Push agent app source code
			gitApp := git.NewCmdConfig(t, git.WithDir(tmpDirApp))
			gitAppRun := func(args ...string) {
				_, err := gitApp.RunCmdE(args...)
				if err != nil {
					t.Fatal(err)
				}
			}

			// copy contents from 6-appsource to the cloned repository
			err = cp.Copy(appSourcePath, fmt.Sprintf("%s/", tmpDirApp))
			if err != nil {
				t.Fatal(err)
			}

			datefile, err := os.OpenFile(fmt.Sprintf("%s/date.txt", tmpDirApp), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
			if err != nil {
				t.Fatal(err)
			}
			defer func() {
				if err := datefile.Close(); err != nil {
					t.Errorf("failed to close datefile: %v", err)
				}
			}()

			_, err = datefile.WriteString(time.Now().String() + "\n")
			if err != nil {
				t.Fatal(err)
			}

			gitAppRun("init", tmpDirApp)
			// gitAppRun("config", "credential.https://source.developers.google.com.helper", "gcloud.sh")
			gitAppRun("config", "user.email", "eab-robot@example.com")
			gitAppRun("config", "user.name", "EAB Robot")
			gitAppRun("config", "init.defaultBranch", "main")
			gitAppRun("config", "http.postBuffer", "157286400")
			gitAppRun("checkout", "-b", "main")
			gitAppRun("remote", "add", "google", appRepo)
			gitApp.AddAll()
			gitApp.CommitWithMsg("initial commit", []string{"--allow-empty"})
			gitAppRun("push", "google", "main", "--force")

			lastCommit := gitApp.GetLatestCommit()
			// filter builds triggered based on pushed commit sha
			buildListCmd := fmt.Sprintf("builds list --region=%s --filter substitutions.COMMIT_SHA='%s' --project %s", region, lastCommit, projectID)
			retriesBuildTrigger := 1
			// poll build until complete
			pollCloudBuild := func(cmd string) func() (bool, error) {
				return func() (bool, error) {
					build := gcloud.Runf(t, cmd).Array()
					if len(build) < 1 {
						if retriesBuildTrigger%3 == 0 {
							// force push to trigger build 1 more time
							t.Logf("Force push again to try trigger build for commit %s", lastCommit)
							gitAppRun("push", "google", "main", "--force")
						}
						retriesBuildTrigger++
						return true, nil
					}
					latestWorkflowRunStatus := build[0].Get("status").String()
					switch latestWorkflowRunStatus {
					case "SUCCESS":
						return false, nil
					case "FAILURE":
						logsCmd := fmt.Sprintf("builds log %s --project=%s --region=%s", build[0].Get("id").String(), build[0].Get("projectId").String(), region)
						logs := gcloud.RunCmd(t, logsCmd)
						t.Logf("%s build-log: %s", serviceName, logs)
						return false, errors.New("Build failed.")
					}
					return true, nil
				}
			}
			utils.Poll(t, pollCloudBuild(buildListCmd), 80, 60*time.Second)

			releaseName := ""
			releaseListCmd := fmt.Sprintf("deploy releases list --project=%s --delivery-pipeline=%s --region=%s --filter=name:%s", projectID, serviceName, region, lastCommit[0:7])
			pollRelease := func(cmd string) func() (bool, error) {
				return func() (bool, error) {
					releases := gcloud.Runf(t, releaseListCmd).Array()
					if len(releases) == 0 {
						return true, nil
					}
					releaseName = releases[0].Get("name").String()
					return false, nil
				}
			}
			utils.Poll(t, pollRelease(releaseListCmd), 80, 60*time.Second)

			// Poll CD rollouts until rollout is successful
			pollCloudDeploy := func(cmd string) func() (bool, error) {
				return func() (bool, error) {
					rollouts := gcloud.Runf(t, cmd).Array()
					if len(rollouts) < 1 {
						return true, nil
					}
					latestRolloutState := rollouts[0].Get("state").String()
					if latestRolloutState == "SUCCEEDED" {
						t.Logf("Rollout finished successfully %s. \n", rollouts[0].Get("targetId"))
						return false, nil
					} else if slices.Contains([]string{"IN_PROGRESS", "PENDING_RELEASE"}, latestRolloutState) {
						t.Logf("Rollout in progress %s. \n", rollouts[0].Get("targetId"))
						return true, nil
					} else {
						logsCmd := fmt.Sprintf("builds log %s --project=%s --region=%s", rollouts[0].Get("deployingBuild").String(), projectID, region)
						logs := gcloud.RunCmd(t, logsCmd)
						isRetryable, message := testutils.IsDeploymentRetryableError(logs)
						if isRetryable {
							t.Logf("Re-trying rollout: %s", message)
							rolloutFullName := strings.Split(rollouts[0].Get("name").String(), "/")
							rolloutName := rolloutFullName[len(rolloutFullName)-1]
							releaseNameParts := strings.Split(releaseName, "/")
							releaseNameFinal := releaseNameParts[len(releaseNameParts)-1]
							gcloud.Run(t, fmt.Sprintf("deploy rollouts retry-job %s --project=%s --delivery-pipeline=%s --region=%s --release=%s --phase-id=stable --job-id=deploy", rolloutName, projectID, serviceName, region, releaseNameFinal))
							return true, nil
						}
						return false, fmt.Errorf("Rollout %s.", latestRolloutState)
					}
				}
			}
			for i, targetId := range deployTargets.Get(repoName).Array() {
				if i > 0 {
					promoteCmd := fmt.Sprintf("deploy releases promote --project=%s --release=%s --delivery-pipeline=%s --region=%s --to-target=%s -q", projectID, releaseName, serviceName, region, targetId)
					t.Logf("Promoting release to next target: %s", targetId)
					// Execute the promote command
					gcloud.Runf(t, promoteCmd)
				}
				rolloutListCmd := fmt.Sprintf("deploy rollouts list --project=%s --delivery-pipeline=%s --region=%s --release=%s --filter targetId=%s", projectID, serviceName, region, releaseName, targetId)
				utils.Poll(t, pollCloudDeploy(rolloutListCmd), 100, 60*time.Second)
			}
		})
		appsource.Test()
	})
}

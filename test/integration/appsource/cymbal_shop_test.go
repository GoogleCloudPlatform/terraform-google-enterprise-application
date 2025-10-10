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

package appsource

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

	cp "github.com/otiai10/copy"
)

func TestSourceCymbalShop(t *testing.T) {

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

	env_cluster_membership_ids := make(map[string]map[string][]string, 0)

	for _, envName := range testutils.EnvNames(t) {
		env_cluster_membership_ids[envName] = make(map[string][]string, 0)
		multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)))
		env_cluster_membership_ids[envName]["cluster_membership_ids"] = testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")
	}

	region := "us-central1" // TODO: Plumb output from appInfra
	appName := "cymbal-shop"
	serviceName := "cymbalshop"
	appSourcePath := fmt.Sprintf("../../../examples/%s/6-appsource/%s", appName, appName)

	appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../4-appfactory/envs/shared"))

	projectID := appFactory.GetJsonOutput("app-group").Get("cymbal-shop\\.cymbalshop.app_admin_project_id").String()
	appInfra := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../examples/%s/5-appinfra/%s/%s/envs/shared", appName, appName, serviceName)))
	deployTargets := appInfra.GetJsonOutput("clouddeploy_targets_names")

	t.Run("replace-repo-contents-and-push", func(t *testing.T) {

		appRepo := fmt.Sprintf("%s/eab-%s-%s", authenticatedUrl, appName, serviceName)
		t.Logf("source-repo: %s", appRepo)

		tmpDirApp := t.TempDir()

		vars := map[string]interface{}{
			"project_id":                 projectID,
			"region":                     region,
			"env_cluster_membership_ids": env_cluster_membership_ids,
			"buckets_force_destroy":      "true",
		}

		appsource := tft.NewTFBlueprintTest(t,
			tft.WithTFDir(appSourcePath),
			tft.WithVars(vars),
			tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		)

		appsource.DefineVerify(func(assert *assert.Assertions) {

			// Push cymbal bank app source code
			gitApp := git.NewCmdConfig(t, git.WithDir(tmpDirApp))
			gitAppRun := func(args ...string) {
				_, err := gitApp.RunCmdE(args...)
				if err != nil {
					t.Fatal(err)
				}
			}

			gitAppRun("clone", "--branch", "v0.10.3", "https://github.com/GoogleCloudPlatform/microservices-demo.git", tmpDirApp)
			gitAppRun("config", "user.email", "eab-robot@example.com")
			gitAppRun("config", "user.name", "EAB Robot")
			// gitAppRun("config", "credential.https://source.developers.google.com.helper", "gcloud.sh")
			gitAppRun("config", "init.defaultBranch", "main")
			gitAppRun("config", "http.postBuffer", "157286400")
			gitAppRun("checkout", "-b", "main")
			gitAppRun("remote", "add", "google", appRepo)

			// copy contents from 6-appsource to the cloned repository
			err := cp.Copy(appSourcePath, tmpDirApp)
			if err != nil {
				t.Fatal(err)
			}

			gitAppRun("add", ".")
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
						return false, errors.New("Build failed.")
					}
					return true, nil
				}
			}
			utils.Poll(t, pollCloudBuild(buildListCmd), 40, 60*time.Second)

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
			utils.Poll(t, pollRelease(releaseListCmd), 40, 60*time.Second)

			targetId := deployTargets.Array()[0]
			rolloutListCmd := fmt.Sprintf("deploy rollouts list --project=%s --delivery-pipeline=%s --region=%s --release=%s --filter targetId=%s", projectID, serviceName, region, releaseName, targetId)
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
						logsCmd := fmt.Sprintf("builds log %s", rollouts[0].Get("deployingBuild").String())
						logs := gcloud.RunCmd(t, logsCmd)
						t.Logf("%s build-log: %s", serviceName, logs)
						return false, fmt.Errorf("Rollout %s.", latestRolloutState)
					}
				}
			}
			utils.Poll(t, pollCloudDeploy(rolloutListCmd), 40, 60*time.Second)
		})
		appsource.Test()
	})

}

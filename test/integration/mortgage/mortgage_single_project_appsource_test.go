// Copyright 2026 Google LLC
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

package mortgage

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/git"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/stretchr/testify/assert"

	cp "github.com/otiai10/copy"
)

func TestSingleProjectSourceMortgage(t *testing.T) {

	env_cluster_membership_ids := make(map[string]map[string][]string, 0)
	// initialize Terraform test from the Blueprints test framework
	gitLabPath := "../../setup/harness/gitlab"
	gitLab := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(gitLabPath))
	projectID := gitLab.GetTFSetupStringOutput("seed_project_id")
	gitUrl := gitLab.GetStringOutput("gitlab_url")
	gitlabPersonalTokenSecretName := gitLab.GetStringOutput("gitlab_pat_secret_name")
	gitlabSecretProject := gitLab.GetStringOutput("gitlab_secret_project")

	appName := "mortgage"
	serviceName := "agent"
	token, err := testutils.GetSecretFromSecretManager(t, gitlabPersonalTokenSecretName, gitlabSecretProject)
	if err != nil {
		t.Fatal(err)
	}

	hostNameWithPath := strings.Split(gitUrl, "https://")[1]
	authenticatedUrl := fmt.Sprintf("https://oauth2:%s@%s/root", token, hostNameWithPath)

	standaloneSingleProj := tft.NewTFBlueprintTest(t, tft.WithVars(map[string]interface{}{"project_id": projectID}), tft.WithTFDir(fmt.Sprintf("../../../examples/%s/standalone-single-project", appName)))

	envName := standaloneSingleProj.GetStringOutput("env")
	env_cluster_membership_ids[envName] = make(map[string][]string, 0)
	env_cluster_membership_ids[envName]["cluster_membership_ids"] = testutils.GetBptOutputStrSlice(standaloneSingleProj, "cluster_membership_ids")
	deployTargets := standaloneSingleProj.GetJsonOutput("clouddeploy_targets_names")

	region := "us-central1"
	repoName := fmt.Sprintf("eab-%s-%s", appName, serviceName)
	appSourcePath := fmt.Sprintf("../../../examples/%s/6-appsource", appName)

	servicePath := fmt.Sprintf("%s/%s", appSourcePath, serviceName)
	t.Log(servicePath)
	t.Run(servicePath, func(t *testing.T) {
		appRepo := fmt.Sprintf("%s/%s", authenticatedUrl, repoName)
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

			gitAppRun("init", tmpDirApp)
			gitAppRun("config", "user.email", "eab-robot@example.com")
			gitAppRun("config", "user.name", "EAB Robot")
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
			onRetryBuild := func() string {
				t.Logf("Force push again to try trigger build for commit %s", lastCommit)
				gitAppRun("push", "google", "main", "--force")
				return ""
			}
			utils.Poll(t, testutils.PollCloudBuild(t, buildListCmd, region, serviceName, onRetryBuild), 40, 60*time.Second)

			releaseName := ""
			releaseListCmd := fmt.Sprintf("deploy releases list --project=%s --delivery-pipeline=%s --region=%s --filter=name:%s", projectID, serviceName, region, lastCommit[0:7])
			utils.Poll(t, testutils.PollCloudDeployRelease(t, releaseListCmd, &releaseName), 60, 60*time.Second)

			testutils.PromoteAndPollCloudDeploy(t, projectID, serviceName, region, releaseName, deployTargets.Array())
		})
		appsource.Test()
	})

}

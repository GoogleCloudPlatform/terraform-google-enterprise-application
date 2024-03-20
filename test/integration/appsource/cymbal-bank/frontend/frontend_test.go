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

package frontend

import (
	"fmt"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/git"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

func TestCymbalBankFrontend(t *testing.T) {

	envName := "development"
	setupOutput := tft.NewTFBlueprintTest(t, tft.WithSetupPath(fmt.Sprintf("../../../../setup")), tft.WithTFDir(fmt.Sprintf("../../../../../")))
	projectID := setupOutput.GetTFSetupStringOutput("project_id")
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../../../2-multitenant/envs/%s", envName)))
	vars := map[string]interface{}{
		"fleet_project_id":      multitenant.GetStringOutput("fleet_project_id"),
		"cluster_membership_id": multitenant.GetStringOutputList("cluster_membership_ids")[0],
	}
	frontend := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(fmt.Sprintf("../../../../../6-appsource/cymbal-bank")),
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)
	frontend.DefineVerify(func(assert *assert.Assertions) {
		frontend.DefaultVerify(assert)

		appRepo := fmt.Sprintf("https://source.developers.google.com/p/%s/r/eab-cymbalbank", projectID)
		region := "us-central1"
		pipelineName := "frontend"
		prodTarget := "development"

		// Push cymbal bank app source code
		tmpDirApp := t.TempDir()
		gitApp := git.NewCmdConfig(t, git.WithDir(tmpDirApp))
		gitAppRun := func(args ...string) {
			_, err := gitApp.RunCmdE(args...)
			if err != nil {
				t.Fatal(err)
			}
		}

		gitAppRun("clone", "--branch", "v0.6.4", "https://github.com/GoogleCloudPlatform/bank-of-anthos.git", tmpDirApp)
		gitAppRun("config", "user.email", "eab-robot@example.com")
		gitAppRun("config", "user.name", "EAB Robot")
		gitAppRun("config", "--global", "credential.https://source.developers.google.com.helper", "gcloud.sh")
		gitAppRun("config", "--global", "init.defaultBranch", "main")
		gitAppRun("config", "--global", "http.postBuffer", "157286400")
		gitAppRun("checkout", "-b", "main")
		gitAppRun("remote", "add", "google", appRepo)
		gitAppRun("add", ".")
		gitApp.CommitWithMsg("initial commit", []string{"--allow-empty"})
		gitAppRun("push", "--all", "google", "-f")

		lastCommit := gitApp.GetLatestCommit()
		// filter builds triggered based on pushed commit sha
		buildListCmd := fmt.Sprintf("builds list --region=%s --filter substitutions.COMMIT_SHA='%s' --project %s", region, lastCommit, projectID)
		// poll build until complete
		pollCloudBuild := func(cmd string) func() (bool, error) {
			return func() (bool, error) {
				build := gcloud.Runf(t, cmd).Array()
				if len(build) < 1 {
					return true, nil
				}
				latestWorkflowRunStatus := build[0].Get("status").String()
				if latestWorkflowRunStatus == "SUCCESS" {
					return false, nil
				}
				return true, nil
			}
		}
		utils.Poll(t, pollCloudBuild(buildListCmd), 40, 30*time.Second)

		releaseName := fmt.Sprintf("release-%s", lastCommit[0:7])
		fmt.Println(releaseName)
		rolloutListCmd := fmt.Sprintf("deploy rollouts list --project=%s --delivery-pipeline=%s --region=%s --release=%s --filter targetId=%s", projectID, pipelineName, region, releaseName, prodTarget)
		// Poll CD rollouts until rollout is successful
		pollCloudDeploy := func(cmd string) func() (bool, error) {
			return func() (bool, error) {
				rollouts := gcloud.Runf(t, cmd).Array()
				if len(rollouts) < 1 {
					return true, nil
				}
				latestRolloutState := rollouts[0].Get("state").String()
				if latestRolloutState == "SUCCEEDED" {
					return false, nil
				}
				return true, nil
			}
		}
		utils.Poll(t, pollCloudDeploy(rolloutListCmd), 30, 60*time.Second)
	})
	frontend.Test()
}

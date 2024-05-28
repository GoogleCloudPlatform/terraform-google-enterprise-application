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
	"os"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/git"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"

	cp "github.com/otiai10/copy"
)

func TestAppSourceContacts(t *testing.T) {
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	multitenant_nonprod := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/non-production"))
	multitenant_prod := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/production"))
	appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../3-appfactory/apps/cymbal-bank"))
	projectID := appFactory.GetJsonOutput("app-group").Get("contacts.app_admin_project_id").String()

	vars := map[string]interface{}{
		"project_id":                     projectID,
		"region":                         testutils.GetBptOutputStrSlice(multitenant, "cluster_regions")[0],
		"cluster_membership_id_dev":      testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")[0],
		"cluster_membership_ids_nonprod": testutils.GetBptOutputStrSlice(multitenant_nonprod, "cluster_membership_ids"),
		"cluster_membership_ids_prod":    testutils.GetBptOutputStrSlice(multitenant_prod, "cluster_membership_ids"),
		"buckets_force_destroy":          "true",
	}
	frontend := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../5-appinfra/apps/accounts-contacts/envs/shared"),
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)
	frontend.DefineVerify(func(assert *assert.Assertions) {
		frontend.DefaultVerify(assert)

		appRepo := fmt.Sprintf("https://source.developers.google.com/p/%s/r/eab-cymbal-bank-accounts-contacts", projectID)
		region := "us-central1"
		pipelineName := "contacts"
		prodTarget := "dev"

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
		datefile, err := os.OpenFile(tmpDirApp+"/src/accounts/date.txt", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err != nil {
			t.Fatal(err)
		}
		defer datefile.Close()

		_, err = datefile.WriteString(time.Now().String() + "\n")
		if err != nil {
			t.Fatal(err)
		}
		gitAppRun("rm", "-r", "src/components")
		err = cp.Copy("../../../6-appsource/cymbal-bank/components", fmt.Sprintf("%s/src/components", tmpDirApp))
		if err != nil {
			t.Fatal(err)
		}
		err = cp.Copy("../../../6-appsource/cymbal-bank/accounts-contacts/skaffold.yaml", fmt.Sprintf("%s/src/accounts/contacts/skaffold.yaml", tmpDirApp))
		if err != nil {
			t.Fatal(err)
		}
		err = cp.Copy("../../../6-appsource/cymbal-bank/accounts-db/k8s/overlays/development/accounts-db.yaml", fmt.Sprintf("%s/src/accounts/accounts-db/k8s/overlays/development/accounts-db.yaml", tmpDirApp))
		if err != nil {
			t.Fatal(err)
		}

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
		releaseListCmd := fmt.Sprintf("deploy releases list --project=%s --delivery-pipeline=%s --region=%s --filter=name:%s", projectID, pipelineName, region, lastCommit[0:7])
		releases := gcloud.Runf(t, releaseListCmd).Array()
		if len(releases) == 0 {
			t.Fatal("Failed to find the release")
		}
		releaseName := releases[0].Get("name")
		fmt.Println(releaseName)
		rolloutListCmd := fmt.Sprintf("deploy rollouts list --project=%s --delivery-pipeline=%s --region=%s --release=%s --filter targetId=%s-%s", projectID, pipelineName, region, releaseName, pipelineName, prodTarget)
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

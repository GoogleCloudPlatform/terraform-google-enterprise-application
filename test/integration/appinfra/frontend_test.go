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
	"strings"
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

func TestAppinfraFrontend(t *testing.T) {
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	multitenant_nonprod := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/non-production"))
	multitenant_prod := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/production"))
	appfactory := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../3-appfactory/apps/cymbal-bank/frontend"))
	projectID := appfactory.GetStringOutput("app_admin_project_id")

	vars := map[string]interface{}{
		"project_id":                     projectID,
		"region":                         multitenant.GetStringOutputList("cluster_regions")[0],
		"cluster_membership_id_dev":      multitenant.GetStringOutputList("cluster_membership_ids")[0],
		"cluster_membership_ids_nonprod": multitenant_nonprod.GetStringOutputList("cluster_membership_ids"),
		"cluster_membership_ids_prod":    multitenant_prod.GetStringOutputList("cluster_membership_ids"),
		"buckets_force_destroy":          "true",
	}
	frontend := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../5-appinfra/apps/frontend/envs/shared"),
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)
	frontend.DefineVerify(func(assert *assert.Assertions) {
		frontend.DefaultVerify(assert)

		serviceName := "frontend"
		applicationName := "cymbal-bank"
		repoName := fmt.Sprintf("eab-%s-%s", applicationName, serviceName)
		appRepo := fmt.Sprintf("https://source.developers.google.com/p/%s/r/%s", repoName, projectID)
		region := "us-central1"
		pipelineName := "frontend"
		prodTarget := "dev"

		prj := gcloud.Runf(t, "projects describe %s", projectID)
		projectNumber := prj.Get("projectNumber").String()
		assert.Equal("ACTIVE", prj.Get("lifecycleState").String(), fmt.Sprintf("project %s should be ACTIVE", projectID))
		apis :=
			[]string{
				"artifactregistry.googleapis.com",
				"sourcerepo.googleapis.com",
				"certificatemanager.googleapis.com",
				"cloudbuild.googleapis.com",
				"clouddeploy.googleapis.com",
				"cloudresourcemanager.googleapis.com",
				"compute.googleapis.com",
				"anthos.googleapis.com",
				"container.googleapis.com",
				"gkehub.googleapis.com",
				"gkeconnect.googleapis.com",
				"anthosconfigmanagement.googleapis.com",
				"mesh.googleapis.com",
				"meshconfig.googleapis.com",
				"meshtelemetry.googleapis.com",
				"iam.googleapis.com",
			}
		enabledAPIS := gcloud.Runf(t, "services list --project %s", projectID).Array()
		listApis := testutils.GetResultFieldStrSlice(enabledAPIS, "config.name")
		assert.Subset(listApis, apis, "APIs should have been enabled")

		art := gcloud.Runf(t, "artifacts repositories describe %s --project %s --location %s", serviceName, projectID, region)
		assert.Equal("DOCKER", art.Get("format").String(), fmt.Sprintf("Repository %s should have type DOCKER", serviceName))

		arRegistryIAMMembers := []string{
			fmt.Sprintf("serviceAccount:%s-compute@developer.gserviceaccount.com", projectNumber),
			fmt.Sprintf("serviceAccount:deploy-%s@%s.iam.gserviceaccount.com", serviceName, projectID),
			"allAuthenticatedUsers",
		}
		arRegistrySAIamFilter := "bindings.role:'roles/artifactregistry.reader'"
		arRegistrySAIamCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", arRegistrySAIamFilter, "--format", "json"})
		arRegistrySAPolicyOp := gcloud.Run(t, fmt.Sprintf("artifacts repositories get-iam-policy %s --location %s --project %s", serviceName, region, projectID), arRegistrySAIamCommonArgs).Array()[0]
		arRegistrySaListMembers := utils.GetResultStrSlice(arRegistrySAPolicyOp.Get("bindings.members").Array())
		assert.Subset(arRegistrySaListMembers, arRegistryIAMMembers, fmt.Sprintf("artifact registry %s should have artifactregistry.reader.", arRegistryIAMMembers))

		cloudDeployServiceAccountEmail := fmt.Sprintf("deploy-%s@%s.iam.gserviceaccount.com", serviceName, projectID)
		gcloud.Runf(t, "iam service-accounts describe %s --project %s", cloudDeployServiceAccountEmail, projectID)

		ciServiceAccountEmail := fmt.Sprintf("ci-%s@%s.iam.gserviceaccount.com", serviceName, projectID)
		gcloud.Runf(t, "iam service-accounts describe %s --project %s", ciServiceAccountEmail, projectID)

		cloudBuildBucketNames := []string{
			fmt.Sprintf("build-cache-%s-%s", serviceName, projectNumber),
			fmt.Sprintf("release-source-development-%s-%s", serviceName, projectNumber),
		}

		pipelinebucketNames := []string{
			fmt.Sprintf("delivery-artifacts-development-%s-%s", projectNumber, serviceName),
			fmt.Sprintf("delivery-artifacts-non-prod-%s-%s", projectNumber, serviceName),
			fmt.Sprintf("delivery-artifacts-prod-%s-%s", projectNumber, serviceName),
		}

		for _, bucketName := range cloudBuildBucketNames {
			bucketOp := gcloud.Runf(t, "storage buckets describe gs://%s --project %s", bucketName, projectID)
			assert.True(bucketOp.Get("uniform_bucket_level_access").Bool(), fmt.Sprintf("Bucket %s should have uniform access level.", bucketName))
			assert.Equal(strings.ToUpper(region), bucketOp.Get("location").String(), fmt.Sprintf("Bucket should be at location %s", region))

			// storage buckets get-iam-policy does not support --filter
			bucketIamCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--format", "json"})
			bucketSAPolicyOp := gcloud.Run(t, fmt.Sprintf("storage buckets get-iam-policy gs://%s", bucketName), bucketIamCommonArgs).Array()
			bucketSaListStorageAdminMembers := testutils.Filter("bindings.role", "roles/storage.admin", bucketSAPolicyOp)
			bucketSaListMembers := utils.GetResultStrSlice(bucketSaListStorageAdminMembers[0].Get("bindings.members").Array())
			assert.Subset(bucketSaListMembers, []string{fmt.Sprintf("serviceAccount:%s", ciServiceAccountEmail)}, fmt.Sprintf("Bucket %s should have storage.admin role for SA %s.", bucketName, ciServiceAccountEmail))
		}

		for _, bucketName := range pipelinebucketNames {
			bucketOp := gcloud.Runf(t, "storage buckets describe gs://%s --project %s", bucketName, projectID)
			assert.True(bucketOp.Get("uniform_bucket_level_access").Bool(), fmt.Sprintf("Bucket %s should have uniform access level.", bucketName))
			assert.Equal(strings.ToUpper(region), bucketOp.Get("location").String(), fmt.Sprintf("Bucket should be at location %s", region))

			// storage buckets get-iam-policy does not support --filter
			bucketIamCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--format", "json"})
			bucketSAPolicyOp := gcloud.Run(t, fmt.Sprintf("storage buckets get-iam-policy gs://%s", bucketName), bucketIamCommonArgs).Array()
			bucketSaListStorageAdminMembers := testutils.Filter("bindings.role", "roles/storage.admin", bucketSAPolicyOp)
			bucketSaListMembers := utils.GetResultStrSlice(bucketSaListStorageAdminMembers[0].Get("bindings.members").Array())
			assert.Subset(bucketSaListMembers, []string{fmt.Sprintf("serviceAccount:%s", cloudDeployServiceAccountEmail)}, fmt.Sprintf("Bucket %s should have storage.admin role for SA %s.", bucketName, cloudDeployServiceAccountEmail))

			if strings.HasPrefix(bucketName, "release") {
				bucketSaListStorageObjectViewerMembers := testutils.Filter("bindings.role", "roles/storage.objectViewer", bucketSAPolicyOp)
				bucketSaListMembers = utils.GetResultStrSlice(bucketSaListStorageObjectViewerMembers[0].Get("bindings.members").Array())
				assert.Subset(bucketSaListMembers, []string{fmt.Sprintf("serviceAccount:%s", cloudDeployServiceAccountEmail)}, fmt.Sprintf("Bucket %s should have storage.objectViewer role for SA %s.", bucketName, cloudDeployServiceAccountEmail))
			}
		}

		// Source Repo Test
		repoPath := fmt.Sprintf("projects/%s/repos/%s", projectID, repoName)
		sourceOp := gcloud.Runf(t, "source repos describe %s --project %s", repoName, projectID)
		assert.Equal(sourceOp.Get("name").String(), repoPath, fmt.Sprintf("Full name of repository should be %s.", repoPath))

		// Project IAM
		computeSARoles := []string{
			"roles/cloudtrace.agent",
			"roles/monitoring.metricWriter",
			"roles/logging.logWriter",
		}
		cbIdentitySARoles := []string{
			"roles/cloudbuild.builds.builder",
		}
		cbSARoles := []string{
			"roles/cloudbuild.builds.builder",
			"roles/clouddeploy.releaser",
			"roles/logging.logWriter",
			"roles/gkehub.viewer",
		}
		cdSARoles := []string{
			"roles/logging.logWriter",
			"roles/gkehub.gatewayEditor",
			"roles/gkehub.viewer",
			"roles/container.developer",
		}

		computeSa := fmt.Sprintf("%s-compute@developer.gserviceaccount.com", projectNumber)
		cbIdentitySa := fmt.Sprintf("%s@cloudbuild.gserviceaccount.com", projectNumber)

		projectIamCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--format", "json"})
		projectSAPolicyOp := gcloud.Run(t, fmt.Sprintf("projects get-iam-policy %s", projectID), projectIamCommonArgs).Array()

		filtered := testutils.Filter("bindings.members", fmt.Sprintf("serviceAccount:%s", computeSa), projectSAPolicyOp)
		projectRoles := testutils.GetResultFieldStrSlice(filtered, "bindings.role")
		assert.Subset(projectRoles, computeSARoles, fmt.Sprintf("Service Account %s should have %v roles at project %s.", computeSa, computeSARoles, projectID))

		filtered = testutils.Filter("bindings.members", fmt.Sprintf("serviceAccount:%s", cbIdentitySa), projectSAPolicyOp)
		projectRoles = testutils.GetResultFieldStrSlice(filtered, "bindings.role")
		assert.Subset(projectRoles, cbIdentitySARoles, fmt.Sprintf("Service Account %s should have %v roles at project %s.", cbIdentitySa, cbIdentitySARoles, projectID))

		filtered = testutils.Filter("bindings.members", fmt.Sprintf("serviceAccount:%s", cloudDeployServiceAccountEmail), projectSAPolicyOp)
		projectRoles = testutils.GetResultFieldStrSlice(filtered, "bindings.role")
		assert.Subset(projectRoles, cdSARoles, fmt.Sprintf("Service Account %s should have %v roles at project %s.", cloudDeployServiceAccountEmail, cdSARoles, projectID))

		filtered = testutils.Filter("bindings.members", fmt.Sprintf("serviceAccount:%s", ciServiceAccountEmail), projectSAPolicyOp)
		projectRoles = testutils.GetResultFieldStrSlice(filtered, "bindings.role")
		assert.Subset(projectRoles, cbSARoles, fmt.Sprintf("Service Account %s should have %v roles at project %s.", ciServiceAccountEmail, cbSARoles, projectID))

		cloudDeployTargets := []string{
			fmt.Sprintf("%s-dev", serviceName),
		}
		for i := range multitenant_nonprod.GetStringOutputList("cluster_membership_ids") {
			cloudDeployTargets = append(cloudDeployTargets, fmt.Sprintf("%s-nonprod-%d", serviceName, i))
		}

		for i := range multitenant_prod.GetStringOutputList("cluster_membership_ids") {
			cloudDeployTargets = append(cloudDeployTargets, fmt.Sprintf("%s-prod-%d", serviceName, i))
		}

		for _, targetName := range cloudDeployTargets {
			deployTargetOp := gcloud.Runf(t, "deploy targets describe %s --project %s --region %s --flatten Target", targetName, projectID, region).Array()[0]
			assert.Equal(cloudDeployServiceAccountEmail, deployTargetOp.Get("executionConfigs").Array()[0].Get("serviceAccount").String(), fmt.Sprintf("cloud deploy target %s should have service account %s", targetName, cloudDeployServiceAccountEmail))
		}

		buildTriggerName := fmt.Sprintf("%s-ci", serviceName)
		ciServiceAccountPath := fmt.Sprintf("projects/%s/serviceAccounts/%s", projectID, ciServiceAccountEmail)
		buildTriggerOp := gcloud.Runf(t, "builds triggers describe %s --project %s --region %s", buildTriggerName, projectID, region)
		assert.Equal(ciServiceAccountPath, buildTriggerOp.Get("serviceAccount").String(), fmt.Sprintf("cloud build trigger %s should have service account %s", buildTriggerName, ciServiceAccountPath))

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
		datefile, err := os.OpenFile(tmpDirApp+"/src/frontend/date.txt", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err != nil {
			t.Fatal(err)
		}
		defer datefile.Close()

		_, err = datefile.WriteString(time.Now().String() + "\n")
		if err != nil {
			t.Fatal(err)
		}
		gitAppRun("rm", "-r", "src/components")
		gitAppRun("rm", "-r", "src/frontend/k8s")
		err = cp.Copy("../../../6-appsource/cymbal-bank/components", fmt.Sprintf("%s/src/components", tmpDirApp))
		if err != nil {
			t.Fatal(err)
		}
		err = cp.Copy("../../../6-appsource/cymbal-bank/frontend/skaffold.yaml", fmt.Sprintf("%s/src/frontend/skaffold.yaml", tmpDirApp))
		if err != nil {
			t.Fatal(err)
		}
		err = cp.Copy("../../../6-appsource/cymbal-bank/frontend/k8s", fmt.Sprintf("%s/src/frontend/k8s", tmpDirApp))
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

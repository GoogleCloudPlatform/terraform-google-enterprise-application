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
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
	"github.com/tidwall/gjson"
)

// TOOD: Update to a single parallel TestAppInfra test
// https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/pull/107
func TestAppInfraFrontend(t *testing.T) {
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	multitenant_nonprod := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/non-production"))
	multitenant_prod := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/production"))
	appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../3-appfactory/apps/cymbal-bank"))
	// TODO: Update to use https://github.com/GoogleCloudPlatform/cloud-foundation-toolkit/pull/2356 when released.
	projectID := gjson.Parse(terraform.OutputJson(t, appFactory.GetTFOptions(), "app-group")).Get("frontend").Get("app_admin_project_id").String()

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
		region := "us-central1"

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
	})
	frontend.Test()
}

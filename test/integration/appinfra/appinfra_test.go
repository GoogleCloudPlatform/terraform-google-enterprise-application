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
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

// TOOD: Update to a single parallel TestAppInfra test
// https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application/pull/107
func TestAppInfra(t *testing.T) {
	env_cluster_membership_ids := make(map[string]map[string][]string, 0)

	for _, envName := range testutils.EnvNames(t) {
		env_cluster_membership_ids[envName] = make(map[string][]string, 0)
		multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)))
		env_cluster_membership_ids[envName]["cluster_membership_ids"] = testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")
	}

	bootstrap := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../1-bootstrap"),
	)

	type ServiceInfos struct {
		ApplicationName string
		ProjectID       string
		ServiceName     string
		TeamName        string
	}
	var (
		prefixServiceName string
		suffixServiceName string
		splitServiceName  []string
	)
	servicesInfoMap := make(map[string]ServiceInfos)
	region := "us-central1" // TODO: Move to terraform.tfvars?

	for appName, serviceNames := range testutils.ServicesNames {
		appName := appName
		appSourcePath := "../../../5-appinfra/apps/default-example"
		appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../4-appfactory/envs/shared"))
		for _, fullServiceName := range serviceNames {
			fullServiceName := fullServiceName // capture range variable
			splitServiceName = strings.Split(fullServiceName, "-")
			prefixServiceName = splitServiceName[0]
			suffixServiceName = splitServiceName[len(splitServiceName)-1]
			suffixServiceName = "hello-world"
			prefixServiceName = "hello-world"
			projectID := appFactory.GetJsonOutput("app-group").Get(fmt.Sprintf("%s\\.%s.app_admin_project_id", appName, "hello-world")).String()
			servicesInfoMap[fullServiceName] = ServiceInfos{
				ApplicationName: appName,
				ProjectID:       projectID,
				ServiceName:     suffixServiceName,
				TeamName:        prefixServiceName,
			}

			remoteState := bootstrap.GetStringOutput("state_bucket")

			backend_bucket := strings.Split(appFactory.GetJsonOutput("app-group").Get("default-example\\.hello-world.app_cloudbuild_workspace_state_bucket_name").String(), "/")
			backendConfig := map[string]interface{}{
				"bucket": backend_bucket[len(backend_bucket)-1],
			}

			servicePath := fmt.Sprintf("%s/%s/envs/shared", appSourcePath, fullServiceName)
			t.Run(servicePath, func(t *testing.T) {
				t.Parallel()

				vars := map[string]interface{}{
					"remote_state_bucket":   remoteState,
					"buckets_force_destroy": "true",
					"environment_names":     testutils.EnvNames(t),
				}

				appService := tft.NewTFBlueprintTest(t,
					tft.WithTFDir(servicePath),
					tft.WithVars(vars),
					tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
					tft.WithBackendConfig(backendConfig),
				)
				appService.DefineVerify(func(assert *assert.Assertions) {
					appService.DefaultVerify(assert)
					repoName := fmt.Sprintf("eab-%s-%s", servicesInfoMap[fullServiceName].ApplicationName, fullServiceName)

					prj := gcloud.Runf(t, "projects describe %s", servicesInfoMap[fullServiceName].ProjectID)
					projectNumber := prj.Get("projectNumber").String()
					assert.Equal("ACTIVE", prj.Get("lifecycleState").String(), fmt.Sprintf("project %s should be ACTIVE", servicesInfoMap[fullServiceName].ProjectID))
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
					enabledAPIS := gcloud.Runf(t, "services list --project %s", servicesInfoMap[fullServiceName].ProjectID).Array()
					listApis := testutils.GetResultFieldStrSlice(enabledAPIS, "config.name")
					assert.Subset(listApis, apis, "APIs should have been enabled")

					art := gcloud.Runf(t, "artifacts repositories describe %s --project %s --location %s", servicesInfoMap[fullServiceName].ServiceName, servicesInfoMap[fullServiceName].ProjectID, region)
					assert.Equal("DOCKER", art.Get("format").String(), fmt.Sprintf("Repository %s should have type DOCKER", fullServiceName))

					arRegistryIAMMembers := []string{
						fmt.Sprintf("serviceAccount:%s-compute@developer.gserviceaccount.com", projectNumber),
						fmt.Sprintf("serviceAccount:deploy-%s@%s.iam.gserviceaccount.com", servicesInfoMap[fullServiceName].ServiceName, servicesInfoMap[fullServiceName].ProjectID),
					}
					arRegistrySAIamFilter := "bindings.role:'roles/artifactregistry.reader'"
					arRegistrySAIamCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", arRegistrySAIamFilter, "--format", "json"})
					arRegistrySAPolicyOp := gcloud.Run(t, fmt.Sprintf("artifacts repositories get-iam-policy %s --location %s --project %s", servicesInfoMap[fullServiceName].ServiceName, region, servicesInfoMap[fullServiceName].ProjectID), arRegistrySAIamCommonArgs).Array()[0]
					arRegistrySaListMembers := utils.GetResultStrSlice(arRegistrySAPolicyOp.Get("bindings.members").Array())
					assert.Subset(arRegistrySaListMembers, arRegistryIAMMembers, fmt.Sprintf("artifact registry %s should have artifactregistry.reader.", arRegistryIAMMembers))

					cloudDeployServiceAccountEmail := fmt.Sprintf("deploy-%s@%s.iam.gserviceaccount.com", servicesInfoMap[fullServiceName].ServiceName, servicesInfoMap[fullServiceName].ProjectID)
					gcloud.Runf(t, "iam service-accounts describe %s --project %s", cloudDeployServiceAccountEmail, servicesInfoMap[fullServiceName].ProjectID)

					ciServiceAccountEmail := fmt.Sprintf("ci-%s@%s.iam.gserviceaccount.com", servicesInfoMap[fullServiceName].ServiceName, servicesInfoMap[fullServiceName].ProjectID)
					gcloud.Runf(t, "iam service-accounts describe %s --project %s", ciServiceAccountEmail, servicesInfoMap[fullServiceName].ProjectID)

					cloudBuildBucketNames := []string{
						fmt.Sprintf("build-cache-%s-%s", servicesInfoMap[fullServiceName].ServiceName, projectNumber),
						fmt.Sprintf("release-source-development-%s-%s", servicesInfoMap[fullServiceName].ServiceName, projectNumber),
					}

					for _, bucketName := range cloudBuildBucketNames {
						bucketOp := gcloud.Runf(t, "storage buckets describe gs://%s --project %s", bucketName, servicesInfoMap[fullServiceName].ProjectID)
						assert.True(bucketOp.Get("uniform_bucket_level_access").Bool(), fmt.Sprintf("Bucket %s should have uniform access level.", bucketName))
						assert.Equal(strings.ToUpper(region), bucketOp.Get("location").String(), fmt.Sprintf("Bucket should be at location %s", region))

						// storage buckets get-iam-policy does not support --filter
						bucketIamCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--format", "json"})
						bucketSAPolicyOp := gcloud.Run(t, fmt.Sprintf("storage buckets get-iam-policy gs://%s", bucketName), bucketIamCommonArgs).Array()
						bucketSaListStorageAdminMembers := testutils.Filter("bindings.role", "roles/storage.admin", bucketSAPolicyOp)
						bucketSaListMembers := utils.GetResultStrSlice(bucketSaListStorageAdminMembers[0].Get("bindings.members").Array())
						assert.Subset(bucketSaListMembers, []string{fmt.Sprintf("serviceAccount:%s", ciServiceAccountEmail)}, fmt.Sprintf("Bucket %s should have storage.admin role for SA %s.", bucketName, ciServiceAccountEmail))
					}

					for env := range env_cluster_membership_ids {
						bucketName := fmt.Sprintf("artifacts-%s-%s-%s", env, projectNumber, servicesInfoMap[fullServiceName].ServiceName)

						bucketOp := gcloud.Runf(t, "storage buckets describe gs://%s --project %s", bucketName, servicesInfoMap[fullServiceName].ProjectID)
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
					repoPath := fmt.Sprintf("projects/%s/repos/%s", servicesInfoMap[fullServiceName].ProjectID, repoName)
					sourceOp := gcloud.Runf(t, "source repos describe %s --project %s", repoName, servicesInfoMap[fullServiceName].ProjectID)
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
					projectSAPolicyOp := gcloud.Run(t, fmt.Sprintf("projects get-iam-policy %s", servicesInfoMap[fullServiceName].ProjectID), projectIamCommonArgs).Array()

					filtered := testutils.Filter("bindings.members", fmt.Sprintf("serviceAccount:%s", computeSa), projectSAPolicyOp)
					projectRoles := testutils.GetResultFieldStrSlice(filtered, "bindings.role")
					assert.Subset(projectRoles, computeSARoles, fmt.Sprintf("Service Account %s should have %v roles at project %s.", computeSa, computeSARoles, servicesInfoMap[fullServiceName].ProjectID))

					filtered = testutils.Filter("bindings.members", fmt.Sprintf("serviceAccount:%s", cbIdentitySa), projectSAPolicyOp)
					projectRoles = testutils.GetResultFieldStrSlice(filtered, "bindings.role")
					assert.Subset(projectRoles, cbIdentitySARoles, fmt.Sprintf("Service Account %s should have %v roles at project %s.", cbIdentitySa, cbIdentitySARoles, servicesInfoMap[fullServiceName].ProjectID))

					filtered = testutils.Filter("bindings.members", fmt.Sprintf("serviceAccount:%s", cloudDeployServiceAccountEmail), projectSAPolicyOp)
					projectRoles = testutils.GetResultFieldStrSlice(filtered, "bindings.role")
					assert.Subset(projectRoles, cdSARoles, fmt.Sprintf("Service Account %s should have %v roles at project %s.", cloudDeployServiceAccountEmail, cdSARoles, servicesInfoMap[fullServiceName].ProjectID))

					filtered = testutils.Filter("bindings.members", fmt.Sprintf("serviceAccount:%s", ciServiceAccountEmail), projectSAPolicyOp)
					projectRoles = testutils.GetResultFieldStrSlice(filtered, "bindings.role")
					assert.Subset(projectRoles, cbSARoles, fmt.Sprintf("Service Account %s should have %v roles at project %s.", ciServiceAccountEmail, cbSARoles, servicesInfoMap[fullServiceName].ProjectID))

					cloudDeployTargets := make([]string, 0)
					for _, v := range env_cluster_membership_ids {
						for _, cluster_membership_id := range v["cluster_membership_ids"] {
							cluster_membership_id := strings.Split(cluster_membership_id, "/")
							cloudDeployTargets = append(cloudDeployTargets, cluster_membership_id[len(cluster_membership_id)-1])
						}
					}

					for _, targetName := range cloudDeployTargets {
						deployTargetOp := gcloud.Runf(t, "deploy targets describe %s --project %s --region %s --flatten Target", strings.TrimPrefix(targetName, "cluster-"), servicesInfoMap[fullServiceName].ProjectID, region).Array()[0]
						assert.Equal(cloudDeployServiceAccountEmail, deployTargetOp.Get("executionConfigs").Array()[0].Get("serviceAccount").String(), fmt.Sprintf("cloud deploy target %s should have service account %s", targetName, cloudDeployServiceAccountEmail))
					}

					buildTriggerName := fmt.Sprintf("%s-ci", fullServiceName)
					ciServiceAccountPath := fmt.Sprintf("projects/%s/serviceAccounts/%s", servicesInfoMap[fullServiceName].ProjectID, ciServiceAccountEmail)
					buildTriggerOp := gcloud.Runf(t, "builds triggers describe %s --project %s --region %s", buildTriggerName, servicesInfoMap[fullServiceName].ProjectID, region)
					assert.Equal(ciServiceAccountPath, buildTriggerOp.Get("serviceAccount").String(), fmt.Sprintf("cloud build trigger %s should have service account %s", buildTriggerName, ciServiceAccountPath))
				})
				appService.Test()
			})
		}
	}
}

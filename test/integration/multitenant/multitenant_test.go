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

package multitenant

import (
	"fmt"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"

	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

func TestMultitenant(t *testing.T) {

	for _, envName := range []string{
		"development",
		"non-production",
		"production",
	} {
		envName := envName
		t.Run(envName, func(t *testing.T) {
			t.Parallel()
			multitenant := tft.NewTFBlueprintTest(t,
				tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)),
				tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
			)

			multitenant.DefineVerify(func(assert *assert.Assertions) {
				multitenant.DefaultVerify(assert)

				// Project IDs
				clusterProjectID := multitenant.GetStringOutput("cluster_project_id")
				fleetProjectID := multitenant.GetStringOutput("fleet_project_id")

				// Projects creation
				for _, projectOutput := range []struct {
					projectId string
					apis      []string
				}{
					{
						projectId: clusterProjectID,
						apis: []string{
							"cloudresourcemanager.googleapis.com",
							"compute.googleapis.com",
							"iam.googleapis.com",
							"serviceusage.googleapis.com",
							"container.googleapis.com",
						},
					},
					{
						projectId: fleetProjectID,
						apis: []string{
							"gkehub.googleapis.com",
							"anthos.googleapis.com",
							"compute.googleapis.com",
							"mesh.googleapis.com",
							"multiclusteringress.googleapis.com",
							"multiclusterservicediscovery.googleapis.com",
						},
					},
				} {
					prj := gcloud.Runf(t, "projects describe %s", projectOutput.projectId)
					assert.Equal("ACTIVE", prj.Get("lifecycleState").String(), fmt.Sprintf("project %s should be ACTIVE", projectOutput.projectId))

					enabledAPIS := gcloud.Runf(t, "services list --project %s", projectOutput.projectId).Array()
					listApis := testutils.GetResultFieldStrSlice(enabledAPIS, "config.name")
					assert.Subset(listApis, projectOutput.apis, "APIs should have been enabled")
				}

				// GKE Cluster
				clusterRegions := terraform.OutputMap(t, multitenant.GetTFOptions(), "cluster_regions")
				clusterIds := terraform.OutputMap(t, multitenant.GetTFOptions(), "clusters_ids")
				listMonitoringEnabledComponents := []string{
					"SYSTEM_COMPONENTS",
					"DEPLOYMENT",
				}

				for _, region := range clusterRegions {
					for _, id := range clusterIds {
						clusterOp := gcloud.Runf(t, "container clusters describe %s --region %s --project %s", id, region, clusterProjectID)
						// NodePool
						assert.Equal("node-pool-1", clusterOp.Get("nodePools.0.name").String(), "NodePool name should be node-pool-1")
						assert.Equal("SURGE", clusterOp.Get("nodePools.0.upgradeSettings.strategy").String(), "NodePool strategy should SURGE")
						assert.Equal("1", clusterOp.Get("nodePools.0.upgradeSettings.maxSurge").String(), "NodePool max surge should be 1")
						assert.Equal("BALANCED", clusterOp.Get("nodePools.0.autoscaling.locationPolicy").String(), "NodePool auto scaling location prolicy should be BALANCED")
						assert.True(clusterOp.Get("nodePools.0.autoscaling.enabled").Bool(), "NodePool auto scaling should be enabled (true)")
						// Cluster
						assert.Equal(fleetProjectID, clusterOp.Get("fleet.project").String(), fmt.Sprintf("Cluster %s Fleet Project should be %s", id, fleetProjectID))
						clusterEnabledComponents := utils.GetResultStrSlice(clusterOp.Get("monitoringConfig.componentConfig.enableComponents").Array())
						assert.Contains(listMonitoringEnabledComponents, clusterEnabledComponents, fmt.Sprintf("Cluster %s should have Monitoring Enabled Components: SYSTEM_COMPONENTS and DEPLOYMENT", id))
						assert.True(clusterOp.Get("monitoringConfig.componentConfig.managedPrometheusConfig").Bool(), fmt.Sprintf("Cluster %s should have Managed Prometheus Config equals True", id))
					}
				}

				// Service Identity
				fleetProjectNumber := gcloud.Runf(t, "projects describe %s", fleetProjectID).Get("projectNumber").String()
				gkeServiceAgent := fmt.Sprintf("service-%s@gcp-sa-gkehub.iam.gserviceaccount.com", fleetProjectNumber)
				gke_sa_roles := []string{
					"roles/gkehub.serviceAgent",
					"roles/gkehub.crossProjectServiceAgent",
				}

				gkeIamFilter := fmt.Sprintf("bindings.members:'serviceAccount:%s'", gkeServiceAgent)
				gkeIamCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", gkeIamFilter, "--format", "json"})
				gkeProjectPolicyOp := gcloud.Run(t, fmt.Sprintf("projects get-iam-policy %s", clusterProjectID), gkeIamCommonArgs).Array()
				gkeSaListRoles := testutils.GetResultFieldStrSlice(gkeProjectPolicyOp, "bindings.role")
				assert.Subset(gkeSaListRoles, gke_sa_roles, fmt.Sprintf("service account %s should have project level roles", gkeServiceAgent))
			})

			multitenant.Test()
		})
	}
}

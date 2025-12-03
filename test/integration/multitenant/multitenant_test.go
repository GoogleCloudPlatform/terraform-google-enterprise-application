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
	"os"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/tidwall/gjson"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

func TestMultitenant(t *testing.T) {

	bootstrap := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../1-bootstrap"),
	)
	err := os.Setenv("GOOGLE_IMPERSONATE_SERVICE_ACCOUNT", bootstrap.GetJsonOutput("cb_service_accounts_emails").Get("multitenant").String())
	if err != nil {
		t.Fatalf("failed to set GOOGLE_IMPERSONATE_SERVICE_ACCOUNT: %v", err)
	}

	vpcsc := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../setup/vpcsc"),
	)

	privateWorkerPoolPath := "../../setup/harness/private_workerpool"
	privateWorkerPool := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(privateWorkerPoolPath),
	)

	multitenantHarnessPath := "../../setup/harness/multitenant"
	multitenantHarness := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(multitenantHarnessPath),
	)

	backend_bucket := bootstrap.GetStringOutput("state_bucket")
	backendConfig := map[string]interface{}{
		"bucket": backend_bucket,
	}

	vars := map[string]interface{}{
		"service_perimeter_name":           vpcsc.GetStringOutput("service_perimeter_name"),
		"service_perimeter_mode":           vpcsc.GetStringOutput("service_perimeter_mode"),
		"access_level_name":                vpcsc.GetStringOutput("access_level_name"),
		"cb_private_workerpool_project_id": privateWorkerPool.GetStringOutput("workerpool_project_id"),
		"envs":                             multitenantHarness.GetJsonOutput("envs").Map(),
	}

	for _, envName := range testutils.EnvNames(t) {
		envName := envName
		t.Run(envName, func(t *testing.T) {
			t.Parallel()
			multitenant := tft.NewTFBlueprintTest(t,
				tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)),
				tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 5, 2*time.Minute),
				tft.WithBackendConfig(backendConfig),
				tft.WithVars(vars),
				tft.WithParallelism(100),
			)

			multitenant.DefineVerify(func(assert *assert.Assertions) {
				multitenant.DefaultVerify(assert)

				// Project IDs
				clusterProjectID := multitenant.GetStringOutput("cluster_project_id")
				fleetProjectID := multitenant.GetStringOutput("fleet_project_id")
				clusterType := multitenant.GetStringOutput("cluster_type")

				// Projects creation
				for _, projectOutput := range []struct {
					projectId string
					apis      []string
				}{
					{
						projectId: clusterProjectID,
						apis: []string{
							"anthos.googleapis.com",
							"anthosconfigmanagement.googleapis.com",
							"anthospolicycontroller.googleapis.com",
							"binaryauthorization.googleapis.com",
							"certificatemanager.googleapis.com",
							"cloudresourcemanager.googleapis.com",
							"cloudtrace.googleapis.com",
							"compute.googleapis.com",
							"container.googleapis.com",
							"containeranalysis.googleapis.com",
							"containerscanning.googleapis.com",
							"gkehub.googleapis.com",
							"iam.googleapis.com",
							"mesh.googleapis.com",
							"multiclusteringress.googleapis.com",
							"multiclusterservicediscovery.googleapis.com",
							"servicenetworking.googleapis.com",
							"serviceusage.googleapis.com",
							"sqladmin.googleapis.com",
							"trafficdirector.googleapis.com",
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
				clusterMembershipIds := testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")
				listMonitoringEnabledComponents := []string{
					"SYSTEM_COMPONENTS",
					"DEPLOYMENT",
				}

				for _, id := range clusterMembershipIds {
					// Membership details
					membershipOp := gcloud.Runf(t, "container fleet memberships describe %s", strings.TrimPrefix(id, "//gkehub.googleapis.com/"))
					// Cluster details
					clusterLocation := regexp.MustCompile(`\/locations\/([^\/]*)\/`).FindStringSubmatch(membershipOp.Get("endpoint.gkeCluster.resourceLink").String())[1]
					clusterName := regexp.MustCompile(`\/clusters\/([^\/]*)$`).FindStringSubmatch(membershipOp.Get("endpoint.gkeCluster.resourceLink").String())[1]
					clusterOp := gcloud.Runf(t, "container clusters describe %s --location %s --project %s", clusterName, clusterLocation, clusterProjectID)

					// Extract enablePrivateEndpoint flag value
					enablePrivateEndpoint := clusterOp.Get("privateClusterConfig.enablePrivateEndpoint").Bool()
					assert.True(enablePrivateEndpoint, "The cluster external endpoint must be private.")

					// Validate if all nodes inside node pool does not contain an external NAT IP address
					nodePoolName := clusterOp.Get("nodePools.0.name").String()
					nodeInstances := gcloud.Runf(t, "compute instances list --filter=\"labels.goog-k8s-node-pool-name=%s\" --project=%s", nodePoolName, clusterProjectID).Array()
					for _, node := range nodeInstances {
						// retrieve all node network interfaces
						nics := node.Get("networkInterfaces")
						// for each network interface, verify if it using an external natIP
						nics.ForEach((func(key, value gjson.Result) bool {
							assert.False(value.Get("accessConfigs.0.natIP").Exists())
							return true // keep iterating
						}))
					}

					// NodePools
					switch clusterType {
					case "STANDARD":
						assert.Equal("node-pool-1", clusterOp.Get("nodePools.0.name").String(), "NodePool name should be node-pool-1")
						assert.Equal("SURGE", clusterOp.Get("nodePools.0.upgradeSettings.strategy").String(), "NodePool strategy should SURGE")
						assert.Equal("1", clusterOp.Get("nodePools.0.upgradeSettings.maxSurge").String(), "NodePool max surge should be 1")
						assert.Equal("BALANCED", clusterOp.Get("nodePools.0.autoscaling.locationPolicy").String(), "NodePool auto scaling location prolicy should be BALANCED")
						assert.True(clusterOp.Get("nodePools.0.autoscaling.enabled").Bool(), "NodePool auto scaling should be enabled (true)")
					case "STANDARD-NAP":
						for _, pool := range clusterOp.Get("nodePools").Array() {
							if pool.Get("name").String() == "node-pool-1" {
								assert.False(pool.Get("autoscaling.autoprovisioned").Bool(), "NodePool autoscaling autoprovisioned should disabled(false)")
							} else if regexp.MustCompile(`^nap-.*`).FindString(pool.Get("name").String()) != "" {
								assert.True(pool.Get("autoscaling.autoprovisioned").Bool(), "NodePool autoscaling autoprovisioned should enabled(true)")
							} else if pool.Get("name").String() != "regional-arm64-pool" {
								t.Fatalf("Error: unknown node pool: %s", pool.Get("name").String())
							}
							// common to all valid node pools
							assert.True(pool.Get("autoscaling.enabled").Bool(), "NodePool auto scaling should be enabled (true)")
							assert.Equal("SURGE", pool.Get("upgradeSettings.strategy").String(), "NodePool strategy should SURGE")
							assert.Equal("1", pool.Get("upgradeSettings.maxSurge").String(), "NodePool max surge should be 1")
							assert.Equal("BALANCED", pool.Get("autoscaling.locationPolicy").String(), "NodePool auto scaling location prolicy should be BALANCED")
						}
					case "AUTOPILOT":
						// Autopilot manages all nodepools
					default:
						t.Fatalf("Error: unknown cluster type: %s", clusterType)
					}
					// Cluster
					assert.Equal(fleetProjectID, clusterOp.Get("fleet.project").String(), fmt.Sprintf("Cluster %s Fleet Project should be %s", id, fleetProjectID))
					clusterEnabledComponents := utils.GetResultStrSlice(clusterOp.Get("monitoringConfig.componentConfig.enableComponents").Array())
					if clusterType != "AUTOPILOT" {
						assert.Equal(listMonitoringEnabledComponents, clusterEnabledComponents, fmt.Sprintf("Cluster %s should have Monitoring Enabled Components: SYSTEM_COMPONENTS and DEPLOYMENT", id))
					}
					assert.True(clusterOp.Get("monitoringConfig.managedPrometheusConfig.enabled").Bool(), fmt.Sprintf("Cluster %s should have Managed Prometheus Config equals True", id))
					assert.Equal(fmt.Sprintf("%s.svc.id.goog", clusterProjectID), clusterOp.Get("workloadIdentityConfig.workloadPool").String(), fmt.Sprintf("Cluster %s workloadPool should be %s.svc.id.goog", id, clusterProjectID))
					assert.Equal(fmt.Sprintf("%s.svc.id.goog", clusterProjectID), membershipOp.Get("authority.workloadIdentityPool").String(), fmt.Sprintf("Membership %s workloadIdentityPool should be %s.svc.id.goog", id, clusterProjectID))
					assert.Equal("PROJECT_SINGLETON_POLICY_ENFORCE", clusterOp.Get("binaryAuthorization.evaluationMode").String(), fmt.Sprintf("Cluster %s Binary Authorization Evaluation Mode should be PROJECT_SINGLETON_POLICY_ENFORCE", id))
				}

				// Service Identity
				fleetProjectNumber := gcloud.Runf(t, "projects describe %s", fleetProjectID).Get("projectNumber").String()
				gkeServiceAgent := fmt.Sprintf("service-%s@gcp-sa-gkehub.iam.gserviceaccount.com", fleetProjectNumber)
				gkeSaRoles := []string{"roles/gkehub.serviceAgent"}

				// If using a seperate fleet project check the cross project SA role
				if fleetProjectID != clusterProjectID {
					gkeSaRoles = append(gkeSaRoles, "roles/gkehub.crossProjectServiceAgent")
				}

				gkeIamFilter := fmt.Sprintf("bindings.members:'serviceAccount:%s'", gkeServiceAgent)
				gkeIamCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", gkeIamFilter, "--format", "json"})
				gkeProjectPolicyOp := gcloud.Run(t, fmt.Sprintf("projects get-iam-policy %s", clusterProjectID), gkeIamCommonArgs).Array()
				gkeSaListRoles := testutils.GetResultFieldStrSlice(gkeProjectPolicyOp, "bindings.role")
				assert.Subset(gkeSaListRoles, gkeSaRoles, fmt.Sprintf("service account %s should have project level roles", gkeServiceAgent))

				// Cloud Armor
				cloudArmorName := "eab-cloud-armor"
				cloudArmorOp := gcloud.Run(t, fmt.Sprintf("compute security-policies describe %s --project %s --format json", cloudArmorName, clusterProjectID)).Array()[0]
				assert.Equal(cloudArmorOp.Get("description").String(), "EAB Cloud Armor policy", "Cloud Armor description should be EAB Cloud Armor policy.")

				// Validate App Ip Addresses exist and are external
				for _, appName := range testutils.AppNames {
					// TODO: Update to use https://github.com/GoogleCloudPlatform/cloud-foundation-toolkit/pull/2356 when released.
					ipAddresses := gjson.Parse(terraform.OutputJson(t, multitenant.GetTFOptions(), "app_ip_addresses")).Get(appName)
					ipAddresses.ForEach(func(key, value gjson.Result) bool {
						ipOp := gcloud.Run(t, fmt.Sprintf("compute addresses describe %s --project %s --global", key, clusterProjectID))
						assert.Equal("EXTERNAL", ipOp.Get("addressType").String(), "External IP type should be EXTERNAL.")
						return true // keep iterating
					})
				}

				cluster_service_accounts := multitenant.GetJsonOutput("cluster_service_accounts").Array()

				assert.Greater(len(cluster_service_accounts), 0, "The terraform output must contain more than 0 service accounts.")
				for _, sa := range cluster_service_accounts {
					assert.True(strings.Contains(sa.String(), ".gserviceaccount.com"), "The cluster SA value must be a Google Service Account")
				}
			})

			multitenant.DefineTeardown(func(assert *assert.Assertions) {
				clusterProjectID := multitenant.GetStringOutput("cluster_project_id")
				// removes firewall rules created by the service but not being deleted.
				firewallRules := gcloud.Runf(t, "compute firewall-rules list  --project %s --filter=\"mcsd\"", clusterProjectID).Array()
				for i := range firewallRules {
					gcloud.Runf(t, "compute firewall-rules delete %s --project %s -q", firewallRules[i].Get("name"), clusterProjectID)
				}

				endpoints := gcloud.Runf(t, "endpoints services list --project %s", clusterProjectID).Array()
				for i := range endpoints {
					gcloud.Runf(t, "endpoints services delete %s --project %s -q", endpoints[i].Get("name"), clusterProjectID)
				}
				multitenant.DefaultTeardown(assert)

			})

			multitenant.Test()
		})
	}
}

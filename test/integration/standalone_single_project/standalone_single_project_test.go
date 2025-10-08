/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// define test package name
package standalone_single_project

import (
	"fmt"
	"net"
	"regexp"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/stretchr/testify/assert"
	"github.com/tidwall/gjson"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

// name the function as Test*
func TestStandaloneSingleProjectExample(t *testing.T) {

	// initialize Terraform test from the Blueprints test framework
	setupOutput := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup/vpcsc"))
	projectID := setupOutput.GetTFSetupStringOutput("seed_project_id")

	singleProjecPath := "../../setup/harness/single_project"
	singleProject := tft.NewTFBlueprintTest(t, tft.WithTFDir(singleProjecPath))

	loggingBucketPath := "../../setup/harness/logging_bucket"
	loggingBucket := tft.NewTFBlueprintTest(t, tft.WithTFDir(loggingBucketPath))

	privateWorkerPoolPath := "../../setup/harness/private_workerpool"
	privateWorkerPool := tft.NewTFBlueprintTest(t, tft.WithTFDir(privateWorkerPoolPath))

	service_perimeter_mode := setupOutput.GetStringOutput("service_perimeter_mode")
	service_perimeter_name := setupOutput.GetStringOutput("service_perimeter_name")
	access_level_name := setupOutput.GetStringOutput("access_level_name")

	vars := map[string]interface{}{
		"project_id":                         projectID,
		"service_perimeter_mode":             service_perimeter_mode,
		"service_perimeter_name":             service_perimeter_name,
		"access_level_name":                  access_level_name,
		"subnetwork_self_link":               singleProject.GetStringOutput("single_project_cluster_subnetwork_self_link"),
		"binary_authorization_repository_id": singleProject.GetStringOutput("binary_authorization_repository_id"),
		"binary_authorization_image":         singleProject.GetStringOutput("binary_authorization_image"),
		"workerpool_network_id":              privateWorkerPool.GetStringOutput("workerpool_network_id"),
		"workerpool_id":                      privateWorkerPool.GetStringOutput("workerpool_id"),
		"logging_bucket":                     loggingBucket.GetStringOutput("logging_bucket"),
		"bucket_kms_key":                     loggingBucket.GetStringOutput("bucket_kms_key"),
		"attestation_kms_key":                loggingBucket.GetStringOutput("attestation_kms_key"),
	}

	// wire setup output project_id to example var.project_id
	standaloneSingleProjT := tft.NewTFBlueprintTest(t,
		tft.WithVars(vars),
		tft.WithTFDir("../../../examples/standalone_single_project"),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)

	// define and write a custom verifier for this test case call the default verify for confirming no additional changes
	standaloneSingleProjT.DefineVerify(func(assert *assert.Assertions) {
		// perform default verification ensuring Terraform reports no additional changes on an applied blueprint
		// standaloneSingleProjT.DefaultVerify(assert)
		clusterMembershipIds := testutils.GetBptOutputStrSlice(standaloneSingleProjT, "cluster_membership_ids")
		clusterType := standaloneSingleProjT.GetStringOutput("cluster_type")
		clusterProjectNumber := standaloneSingleProjT.GetStringOutput("cluster_project_number")
		clusterRegions := testutils.GetBptOutputStrSlice(standaloneSingleProjT, "cluster_regions")
		envName := standaloneSingleProjT.GetStringOutput("env")
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
			clusterOp := gcloud.Runf(t, "container clusters describe %s --location %s --project %s", clusterName, clusterLocation, projectID)

			// Extract enablePrivateEndpoint flag value
			enablePrivateEndpoint := clusterOp.Get("privateClusterConfig.enablePrivateEndpoint").Bool()
			assert.True(enablePrivateEndpoint, "The cluster external endpoint must be private.")

			// Validate if all nodes inside node pool does not contain an external NAT IP address
			nodePoolName := clusterOp.Get("nodePools.0.name").String()
			nodeInstances := gcloud.Runf(t, "compute instances list --filter=\"labels.goog-k8s-node-pool-name=%s\" --project=%s", nodePoolName, projectID).Array()
			for _, node := range nodeInstances {
				// retrieve all node network interfaces
				nics := node.Get("networkInterfaces")
				// for each network interface, verify if it using an external natIP
				nics.ForEach((func(key, value gjson.Result) bool {
					assert.Equal(net.IP(nil), net.ParseIP(value.Get("accessConfigs.0.natIP").String()), "The nodes inside the nodepool should not have external ip addresses.")
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
					} else {
						if pool.Get("name").String() != "arm-node-pool" {
							t.Fatalf("Error: unknown node pool: %s", pool.Get("name").String())
						}
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
			assert.Equal(projectID, clusterOp.Get("fleet.project").String(), fmt.Sprintf("Cluster %s Fleet Project should be %s", id, projectID))
			clusterEnabledComponents := utils.GetResultStrSlice(clusterOp.Get("monitoringConfig.componentConfig.enableComponents").Array())
			if clusterType != "AUTOPILOT" {
				assert.Equal(listMonitoringEnabledComponents, clusterEnabledComponents, fmt.Sprintf("Cluster %s should have Monitoring Enabled Components: SYSTEM_COMPONENTS and DEPLOYMENT", id))
			}
			assert.True(clusterOp.Get("monitoringConfig.managedPrometheusConfig.enabled").Bool(), fmt.Sprintf("Cluster %s should have Managed Prometheus Config equals True", id))
			assert.Equal(fmt.Sprintf("%s.svc.id.goog", projectID), clusterOp.Get("workloadIdentityConfig.workloadPool").String(), fmt.Sprintf("Cluster %s workloadPool should be %s.svc.id.goog", id, projectID))
			assert.Equal(fmt.Sprintf("%s.svc.id.goog", projectID), membershipOp.Get("authority.workloadIdentityPool").String(), fmt.Sprintf("Membership %s workloadIdentityPool should be %s.svc.id.goog", id, projectID))
			assert.Equal("PROJECT_SINGLETON_POLICY_ENFORCE", clusterOp.Get("binaryAuthorization.evaluationMode").String(), fmt.Sprintf("Cluster %s Binary Authorization Evaluation Mode should be PROJECT_SINGLETON_POLICY_ENFORCE", id))

		}

		// Service Identity
		fleetProjectNumber := gcloud.Runf(t, "projects describe %s", projectID).Get("projectNumber").String()
		gkeServiceAgent := fmt.Sprintf("service-%s@gcp-sa-gkehub.iam.gserviceaccount.com", fleetProjectNumber)
		gkeSaRoles := []string{"roles/gkehub.serviceAgent"}

		gkeIamFilter := fmt.Sprintf("bindings.members:'serviceAccount:%s'", gkeServiceAgent)
		gkeIamCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", gkeIamFilter, "--format", "json"})
		gkeProjectPolicyOp := gcloud.Run(t, fmt.Sprintf("projects get-iam-policy %s", projectID), gkeIamCommonArgs).Array()
		gkeSaListRoles := testutils.GetResultFieldStrSlice(gkeProjectPolicyOp, "bindings.role")
		assert.Subset(gkeSaListRoles, gkeSaRoles, fmt.Sprintf("service account %s should have project level roles", gkeServiceAgent))

		// Cloud Armor
		cloudArmorName := "eab-cloud-armor"
		cloudArmorOp := gcloud.Run(t, fmt.Sprintf("compute security-policies describe %s --project %s --format json", cloudArmorName, projectID)).Array()[0]
		assert.Equal(cloudArmorOp.Get("description").String(), "EAB Cloud Armor policy", "Cloud Armor description should be EAB Cloud Armor policy.")

		cluster_service_accounts := standaloneSingleProjT.GetJsonOutput("cluster_service_accounts").Array()

		assert.Greater(len(cluster_service_accounts), 0, "The terraform output must contain more than 0 service accounts.")
		for _, sa := range cluster_service_accounts {
			assert.True(strings.Contains(sa.String(), ".gserviceaccount.com"), "The cluster SA value must be a Google Service Account")
		}

		gkeMeshCommand := fmt.Sprintf("beta container fleet mesh describe --project %s --format='json(membershipStates)'", projectID)

		membershipNamesProjectNumber := []string{}
		for _, region := range clusterRegions {
			membershipName := fmt.Sprintf("projects/%[1]s/locations/%[2]s/memberships/cluster-%[2]s-%[3]s", clusterProjectNumber, region, envName)
			membershipNamesProjectNumber = append(membershipNamesProjectNumber, membershipName)
		}
		pollMeshProvisioning := func(cmd string) func() (bool, error) {
			return func() (bool, error) {
				retry := false
				result := gcloud.Runf(t, cmd)
				if len(result.Array()) < 1 {
					return true, nil
				}
				for _, memberShipName := range membershipNamesProjectNumber {
					dataPlaneManagement := result.Get("membershipStates").Get(memberShipName).Get("servicemesh.dataPlaneManagement.state").String()
					controlPlaneManagement := result.Get("membershipStates").Get(memberShipName).Get("servicemesh.controlPlaneManagement.state").String()
					retryStatus := []string{"PROVISIONING", "STALLED"}
					if slices.Contains(retryStatus, dataPlaneManagement) || slices.Contains(retryStatus, controlPlaneManagement) {
						retry = true
					} else if dataPlaneManagement != "ACTIVE" || controlPlaneManagement != "ACTIVE" {
						generalState := result.Get("membershipStates").Get(memberShipName).Get("state.code").String()
						generalDescription := result.Get("membershipStates").Get(memberShipName).Get("state.description").String()
						return false, fmt.Errorf("Service mesh provisioning failed for %s: status='%s' description='%s'", memberShipName, generalState, generalDescription)
					}
				}
				return retry, nil
			}
		}
		if envName != "development" {
			utils.Poll(t, pollMeshProvisioning(gkeMeshCommand), 10, 60*time.Second)
		}
	})

	standaloneSingleProjT.DefineTeardown(func(assert *assert.Assertions) {
		// removes firewall rules created by the service but not being deleted.
		firewallRules := gcloud.Runf(t, "compute firewall-rules list  --project %s --filter=\"mcsd\"", projectID).Array()
		for i := range firewallRules {
			gcloud.Runf(t, "compute firewall-rules delete %s --project %s -q", firewallRules[i].Get("name"), projectID)
		}
		standaloneSingleProjT.DefaultTeardown(assert)

	})
	// call the test function to execute the integration test
	standaloneSingleProjT.Test()
}

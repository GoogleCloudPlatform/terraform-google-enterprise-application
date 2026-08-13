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

package cluster_multitenant_discovery

import (
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/assert"
	"github.com/tidwall/gjson"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

func TestMultiClusterDiscovery(t *testing.T) {
	setup := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../setup"),
	)

	vpcsc := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../setup/vpcsc"),
	)

	loggingHarnessPath := "../../setup/harness/logging_bucket"
	loggingHarness := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(loggingHarnessPath),
	)
	
	envName := "development"
	forkRepository := os.Getenv("HEAD_REPO_URL")
	branch := os.Getenv("HEAD_BRANCH")
	configSyncPath := os.Getenv("CONFIG_SYNC_PATH")
	if forkRepository == "" || branch == "" {
		forkRepository = "https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application"
		branch = "main"
		configSyncPath = fmt.Sprintf("examples/cymbal-bank/3-fleetscope/config-sync/%s", envName)
	}

	vars := map[string]interface{}{
		"service_perimeter_name":     vpcsc.GetStringOutput("service_perimeter_name"),
		"service_perimeter_mode":     vpcsc.GetStringOutput("service_perimeter_mode"),
		"access_level_name":          vpcsc.GetStringOutput("access_level_name"),
		"attestation_kms_key":        loggingHarness.GetStringOutput("attestation_kms_key"),
		"regions":                    []string{"us-central1", "us-east4"},
		"project_id":                 setup.GetStringOutput("seed_project_id"),
		"config_sync_secret_type":    "none",
		"config_sync_repository_url": forkRepository,
		"config_sync_policy_dir":     configSyncPath,
		"config_sync_branch":         branch,
	}

	setupNamespaces := setup.GetJsonOutput("teams")
	var namespacesSlice []string
	setupNamespaces.ForEach(func(key, value gjson.Result) bool {
		namespacesSlice = append(namespacesSlice, key.String())
		return true // keep iterating
	})
	t.Run("examples/cluster-multicluster-discovery", func(t *testing.T) {
		multitenant := tft.NewTFBlueprintTest(t,
			tft.WithTFDir("../../../examples/cluster-multicluster-discovery"),
			tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 5, 2*time.Minute),
			tft.WithVars(vars),
		)

		multitenant.DefineVerify(func(assert *assert.Assertions) {
			multitenant.DefaultVerify(assert)

			// Project IDs
			clusterProjectID := multitenant.GetStringOutput("cluster_project_id")
			fleetProjectID := multitenant.GetStringOutput("fleet_project_id")
			clusterType := multitenant.GetStringOutput("cluster_type")
			clusterMembership := multitenant.GetJsonOutput("cluster_membership_ids").Array()[0].String()
			splitClusterMembership := strings.Split(clusterMembership, "/")
			clusterName := splitClusterMembership[len(splitClusterMembership)-1]
			clusterRegions := multitenant.GetJsonOutput("cluster_regions").Array()

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
						assert.Equal("BALANCED", pool.Get("autoscaling.locationPolicy").String(), "NodePool auto scaling location policy should be BALANCED")
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
				ipAddresses := multitenant.GetJsonOutput("app_ip_addresses").Get(appName).Map()
				for k, v := range ipAddresses {
					ipOp := gcloud.Run(t, fmt.Sprintf("compute addresses describe %s --project %s --global", k, clusterProjectID))
					assert.Equal("EXTERNAL", ipOp.Get("addressType").String(), "External IP type should be EXTERNAL.")
					assert.Equal(v.String(), ipOp.Get("address").String(), fmt.Sprintf("IP should have same value as output value. Expected: %s, got: %s", v.String(), ipOp.Get("address").String()))
				}
			}

			cluster_service_accounts := multitenant.GetJsonOutput("cluster_service_accounts").Array()

			assert.Greater(len(cluster_service_accounts), 0, "The terraform output must contain more than 0 service accounts.")
			for _, sa := range cluster_service_accounts {
				assert.True(strings.Contains(sa.String(), ".gserviceaccount.com"), "The cluster SA value must be a Google Service Account")
			}

			var currentEnvNamespaces []string
			for _, namespace := range namespacesSlice {
				currentEnvNamespaces = append(currentEnvNamespaces, fmt.Sprintf("%s-%s", namespace, envName))
			}

			for _, region := range clusterRegions {
				testutils.ConnectToFleet(t, clusterName, region.String(), clusterProjectID)
				k8sOpts := k8s.NewKubectlOptions(fmt.Sprintf("connectgateway_%s_%s_%s", clusterProjectID, region, clusterName), "", "")

				pollNamespaces := func() (bool, error) {
					// get kubectl namespaces and store them on currentClusterNamespaces slice
					output, err := k8s.RunKubectlAndGetOutputE(t, k8sOpts, "get", "ns", "-o", "json")
					if err != nil {
						t.Fatal(err)
					}
					if !gjson.Valid(output) {
						t.Fatalf("Error parsing output, invalid json: %s", output)
					}
					jsonOutput := gjson.Parse(output)
					var currentClusterNamespaces []string
					jsonOutput.Get("items").ForEach(func(key, value gjson.Result) bool {
						currentClusterNamespaces = append(currentClusterNamespaces, value.Get("metadata.name").String())
						return true // keep iterating
					})

					for _, namespace := range currentEnvNamespaces {
						// Check if the namespace exists in currentClusterNamespaces
						exists := false
						for _, clusterNamespace := range currentClusterNamespaces {
							if namespace == clusterNamespace {
								exists = true
								break
							}
						}

						if exists {
							t.Logf("Namespace found: %s \n", namespace)
							return false, nil
						} else {
							t.Logf("Namespace NOT found: %s \n", namespace)
							return true, fmt.Errorf("Namespace '%s' does not exist in the current cluster.\n", namespace)
						}
					}
					t.Logf("There are no namespaces %v \n", k8sOpts)
					return true, fmt.Errorf("Namespaces not found in %v.\n", k8sOpts)
				}
				utils.Poll(t, pollNamespaces, 20, 30*time.Second)

				// Multitenant Outputs

				clusterMembershipIds := testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")
				clusterProjectID := multitenant.GetStringOutput("cluster_project_id")
				clusterProjectNumber := multitenant.GetStringOutput("cluster_project_number")

				membershipNames := []string{}
				membershipName := fmt.Sprintf("projects/%[1]s/locations/%[2]s/memberships/cluster-%[2]s-%[3]s", clusterProjectID, region, envName)
				membershipNames = append(membershipNames, membershipName)
				membershipNamesProjectNumber := []string{}
				membershipName = fmt.Sprintf("projects/%[1]s/locations/%[2]s/memberships/cluster-%[2]s-%[3]s", clusterProjectNumber, region, envName)
				membershipNamesProjectNumber = append(membershipNamesProjectNumber, membershipName)
				// GKE Feature
				features := []string{
					"configmanagement",
					"servicemesh",
					"policycontroller",
					"multiclusteringress",
					"multiclusterservicediscovery",
				}

				for _, feature := range features {
					gkeFeatureOp := gcloud.Runf(t, "container hub features describe %s --project %s", feature, clusterProjectID)
					assert.Equal("ACTIVE", gkeFeatureOp.Get("resourceState.state").String(), fmt.Sprintf("Hub Feature %s should have resource state equal to ACTIVE", feature))

					switch feature {
					case "servicemesh":
						// Service Mesh Management
						{
							assert.Equal("MANAGEMENT_AUTOMATIC", gkeFeatureOp.Get("fleetDefaultMemberConfig.mesh.management").String(), fmt.Sprintf("Hub Feature %s should have mesh menagement equal to MANAGEMENT_AUTOMATIC", feature))
						}
					case "multiclusteringress":
						// Multicluster Ingress Membership
						{
							assert.Contains(membershipNames, gkeFeatureOp.Get("spec.multiclusteringress.configMembership").String(), fmt.Sprintf("Hub Feature %s should have Config Membership in one region", feature))
						}
					case "configmanagement":
						// GKE Feature Membership
						{
							fleetProjectNumber := gcloud.Runf(t, "projects describe %s", clusterProjectID).Get("projectNumber").String()
							membershipName := fmt.Sprintf("projects/%[1]s/locations/%[2]s/memberships/cluster-%[2]s-%[3]s", fleetProjectNumber, region, envName)
							configmanagementPath := fmt.Sprintf("membershipSpecs.%s.configmanagement", membershipName)

							assert.Equal("unstructured", gkeFeatureOp.Get(configmanagementPath+".configSync.sourceFormat").String(), fmt.Sprintf("Hub Feature %s should have source format equal to unstructured", membershipName))
							assert.Equal("1.23.3", gkeFeatureOp.Get(configmanagementPath+".version").String(), fmt.Sprintf("Hub Feature %s should have source format equal to unstructured", membershipName))
						}
					case "policycontroller":
						// GKE Policy Controller Membership
						{
							for _, region := range clusterRegions {
								fleetProjectNumber := gcloud.Runf(t, "projects describe %s", clusterProjectID).Get("projectNumber").String()
								membershipName := fmt.Sprintf("projects/%[1]s/locations/%[2]s/memberships/cluster-%[2]s-%[3]s", fleetProjectNumber, region, envName)
								policycontrollerPath := fmt.Sprintf("membershipSpecs.%s.policycontroller", membershipName)

								assert.Equal("INSTALL_SPEC_ENABLED", gkeFeatureOp.Get(policycontrollerPath+".policyControllerHubConfig.installSpec").String(), fmt.Sprintf("Hub Feature %s policy controller should be INSTALL_SPEC_ENABLED", membershipName))
								assert.Equal("ALL", gkeFeatureOp.Get(policycontrollerPath+".policyControllerHubConfig.policyContent.templateLibrary.installation").String(), fmt.Sprintf("Hub Feature %s policy controller templateLibrary should be ALL", membershipName))

							}
						}

						pollConfigSync := func() (bool, error) {
							retry := false
							// ensure config-sync resources are present in cluster
							_, err := k8s.RunKubectlAndGetOutputE(t, k8sOpts, "get", "rootsyncs.configsync.gke.io", "-n", "config-management-system", "root-sync", "-o", "jsonpath='{.status}'")
							if err != nil {
								if !strings.Contains(err.Error(), "Error from server (NotFound): rootsyncs.configsync.gke.io \"root-sync\" not found") &&
									!strings.Contains(err.Error(), "the server doesn't have a resource type \"rootsyncs\"") {
									t.Logf("Config-Sync error '%s' \n.", err.Error())
									return false, err
								} else {
									t.Log("Config-Sync not yet installed, will try polling again after sleeping.")
									retry = true
								}
							}
							return retry, nil
						}

						utils.Poll(t, pollConfigSync, 20, 40*time.Second)
					}
				}

				// GKE Membership binding
				for _, id := range clusterMembershipIds {
					membershipOp := gcloud.Runf(t, "container fleet memberships describe %s", strings.TrimPrefix(id, "//gkehub.googleapis.com/"))
					assert.Equal(fmt.Sprintf("%s.svc.id.goog", clusterProjectID), membershipOp.Get("authority.workloadIdentityPool").String(), fmt.Sprintf("Membership %s workloadIdentityPool should be %s.svc.id.goog", id, clusterProjectID))
				}

				// GKE Scopes and Namespaces
				for _, namespaces := range currentEnvNamespaces {
					gkeScopes := fmt.Sprintf("projects/%s/locations/global/scopes/%s", clusterProjectID, namespaces)
					opGKEScopes := gcloud.Runf(t, "container fleet scopes describe projects/%[1]s/locations/global/scopes/%[2]s --project=%[1]s", clusterProjectID, namespaces)
					gkeNamespaces := fmt.Sprintf("projects/%[1]s/locations/global/scopes/%[2]s/namespaces/%[2]s", clusterProjectID, namespaces)
					opNamespaces := gcloud.Runf(t, "container hub scopes namespaces describe projects/%[1]s/locations/global/scopes/%[2]s/namespaces/%[2]s --project=%[1]s", clusterProjectID, namespaces)
					assert.Equal(gkeNamespaces, opNamespaces.Get("name").String(), fmt.Sprintf("The GKE Namespace should be %s", gkeNamespaces))
					assert.True(opNamespaces.Exists(), "Namespace %s should exist", gkeNamespaces)
					assert.Equal(gkeScopes, opGKEScopes.Get("name").String(), fmt.Sprintf("The GKE Namespace should be %s", gkeScopes))
					assert.True(opGKEScopes.Exists(), "Namespace %s should exist", gkeScopes)
				}
				gkeMeshCommand := fmt.Sprintf("beta container fleet mesh describe --project %s --format='json(membershipStates)'", clusterProjectID)
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

				pollPolicyControllerState := func() (bool, error) {
					booleans := make([]bool, len(membershipNamesProjectNumber))
					for i, membershipName := range membershipNamesProjectNumber {
						gcloudCmdOutput := gcloud.Runf(t, "container fleet policycontroller describe --memberships=%s --project=%s", membershipName, clusterProjectID)
						if len(gcloudCmdOutput.Array()) < 1 {
							return true, nil
						}
						admissionState := gcloudCmdOutput.Get("membershipStates").Get(membershipName).Get("policycontroller.componentStates.admission.state").String()
						auditState := gcloudCmdOutput.Get("membershipStates").Get(membershipName).Get("policycontroller.componentStates.audit.state").String()
						booleans[i] = (auditState == "ACTIVE" && admissionState == "ACTIVE")
					}
					// stop retrying when all clusters have the policy controller in the active state
					return !testutils.AllTrue(booleans), nil
				}

				pollPoliciesInstallationState := func() (bool, error) {
					booleans := make([]bool, len(membershipNamesProjectNumber))
					for i, membershipName := range membershipNamesProjectNumber {
						gcloudCmdOutput := gcloud.Runf(t, "container fleet policycontroller describe --memberships=%s --project=%s", membershipName, clusterProjectID)
						if len(gcloudCmdOutput.Array()) < 1 {
							return true, nil
						}
						pss := gcloudCmdOutput.Get("membershipStates").Get(membershipName).Get("policycontroller.policyContentState.bundleStates.pss-baseline-v2022.state").String()
						policyessentials := gcloudCmdOutput.Get("membershipStates").Get(membershipName).Get("policycontroller.policyContentState.bundleStates.policy-essentials-v2022.state").String()
						booleans[i] = (pss == "ACTIVE" && policyessentials == "ACTIVE")
						t.Logf("booleans[%d]: %v", i, booleans[i])
					}
					return !testutils.AllTrue(booleans), nil
				}

				if envName != "development" {
					utils.Poll(t, pollMeshProvisioning(gkeMeshCommand), 10, 60*time.Second)
				}
				utils.Poll(t, pollPolicyControllerState, 20, 30*time.Second)
				utils.Poll(t, pollPoliciesInstallationState, 20, 30*time.Second)

				noError := false
				for count := 0; count < 10; count++ {

					// validate no errors in config sync
					output, err := k8s.RunKubectlAndGetOutputE(t, k8sOpts, "get", "rootsyncs.configsync.gke.io", "-n", "config-management-system", "root-sync", "-o", "jsonpath='{.status}'")
					if err != nil {
						t.Fatal(err)
					}
					// jsonpath adds ' character to string, that need to be removed for a valid json
					output = strings.ReplaceAll(output, "'", "")
					assert.True(gjson.Valid(output), "kubectl rootsyncs command output must be a valid gjson.")
					jsonOutput := gjson.Parse(output)
					noErrors := func() bool {
						t.Logf("noError() jsonOutput: %v", jsonOutput.String())

						t.Logf("source.errorSummary equals {} or empty: %v", jsonOutput.Get("source.errorSummary").String() == "{}" || jsonOutput.Get("source.errorSummary").String() == "")
						t.Logf("sync.errorSummary equals {} or empty: %v", jsonOutput.Get("sync.errorSummary").String() == "{}" || jsonOutput.Get("source.errorSummary").String() == "")
						t.Logf("rendering.errorSummary equals {} or empty: %v", jsonOutput.Get("rendering.errorSummary").String() == "{}" || jsonOutput.Get("source.errorSummary").String() == "")

						return (jsonOutput.Get("sync.errorSummary").String() == "{}" || jsonOutput.Get("sync.errorSummary").String() == "") &&
							(jsonOutput.Get("source.errorSummary").String() == "{}" || jsonOutput.Get("source.errorSummary").String() == "") &&
							(jsonOutput.Get("rendering.errorSummary").String() == "{}" || jsonOutput.Get("rendering.errorSummary").String() == "")
					}
					noError = noErrors()
					t.Logf("noError var: %v", noError)
					if noError {
						break
					} else {
						time.Sleep(60 * time.Second)
					}
				}
				if !noError {
					t.Fatal("ERROR: config-sync should not have errors.")
				}
			}
		})

		multitenant.DefineTeardown(func(assert *assert.Assertions) {
			// clusterProjectID := multitenant.GetStringOutput("cluster_project_id")
			// // removes firewall rules created by the service but not being deleted.
			// firewallRules := gcloud.Runf(t, "compute firewall-rules list  --project %s --filter=\"mcsd\"", clusterProjectID).Array()
			// for i := range firewallRules {
			// 	gcloud.Runf(t, "compute firewall-rules delete %s --project %s -q", firewallRules[i].Get("name"), clusterProjectID)
			// }

			// endpoints := gcloud.Runf(t, "endpoints services list --project %s", clusterProjectID).Array()
			// for i := range endpoints {
			// 	gcloud.Runf(t, "endpoints services delete %s --project %s -q", endpoints[i].Get("name"), clusterProjectID)
			// }
			multitenant.DefaultTeardown(assert)

		})

		multitenant.Test()
	})
}

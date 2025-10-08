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

package fleetscope

import (
	"fmt"
	"maps"
	"os"
	"slices"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/stretchr/testify/assert"
	"github.com/tidwall/gjson"
)

func renameKueueFile(t *testing.T) {
	tf_file_old := "../../../3-fleetscope/modules/env_baseline/kueue.tf.example"
	tf_file_new := "../../../3-fleetscope/modules/env_baseline/kueue.tf"
	err := os.Rename(tf_file_old, tf_file_new)
	if err != nil {
		// Test if the error is because the file was already move in other environment test
		if !strings.Contains(err.Error(), "no such file or directory") {
			t.Fatal(err)
		}
	}
}

func TestFleetscope(t *testing.T) {
	setup := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup"))
	bootstrap := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../1-bootstrap"),
	)

	hpc, err := strconv.ParseBool(setup.GetTFSetupStringOutput("hpc"))
	if err != nil {
		hpc = false
	}

err = os.Setenv("GOOGLE_IMPERSONATE_SERVICE_ACCOUNT", bootstrap.GetJsonOutput("cb_service_accounts_emails").Get("fleetscope").String())
if err != nil {
	t.Fatalf("failed to set GOOGLE_IMPERSONATE_SERVICE_ACCOUNT: %v", err)
}

	backend_bucket := bootstrap.GetStringOutput("state_bucket")
	backendConfig := map[string]interface{}{
		"bucket": backend_bucket,
	}

	multitenantHarnessPath := "../../setup/harness/multitenant"
	multitenantHarness := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(multitenantHarnessPath),
	)

	loggingHarnessPath := "../../setup/harness/logging_bucket"
	loggingHarness := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(loggingHarnessPath),
	)

	attestation := map[string]interface{}{}

	if len(testutils.EnvNames(t)) == 1 {
		attestation = map[string]interface{}{"attestation_evaluation_mode": multitenantHarness.GetStringOutput("attestation_evaluation_mode")}
	}

	for _, envName := range testutils.EnvNames(t) {
		envName := envName
		// retrieve namespaces from test/setup, they will be used to create the specific namespaces with the environment suffix
		setupNamespaces := setup.GetJsonOutput("teams")
		var namespacesSlice []string
		setupNamespaces.ForEach(func(key, value gjson.Result) bool {
			namespacesSlice = append(namespacesSlice, key.String())
			return true // keep iterating
		})

		t.Run(envName, func(t *testing.T) {
			t.Parallel()
			// each namespace will have the current environment suffixed
			var currentEnvNamespaces []string
			for _, namespace := range namespacesSlice {
				currentEnvNamespaces = append(currentEnvNamespaces, fmt.Sprintf("%s-%s", namespace, envName))
			}
			multitenant := tft.NewTFBlueprintTest(t,
				tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)),
				tft.WithBackendConfig(backendConfig),
			)

			// retrieve cluster location and fleet membership from 2-multitenant
			clusterProjectId := multitenant.GetJsonOutput("cluster_project_id").String()
			clusterLocation := multitenant.GetJsonOutput("cluster_regions").Array()[0].String()
			clusterMembership := multitenant.GetJsonOutput("cluster_membership_ids").Array()[0].String()

			// extract clusterName from fleet membership id
			splitClusterMembership := strings.Split(clusterMembership, "/")
			clusterName := splitClusterMembership[len(splitClusterMembership)-1]

			testutils.ConnectToFleet(t, clusterName, clusterLocation, clusterProjectId)

			vars := map[string]interface{}{
				"remote_state_bucket":         backend_bucket,
				"namespace_ids":               setup.GetJsonOutput("teams").Value().(map[string]interface{}),
				"config_sync_secret_type":     "none",
				"config_sync_repository_url":  "https://github.com/GoogleCloudPlatform/terraform-google-enterprise-application",
				"config_sync_policy_dir":      fmt.Sprintf("examples/cymbal-bank/3-fleetscope/config-sync/%s", envName),
				"config_sync_branch":          "main",
				"disable_istio_on_namespaces": []string{"cymbalshops", "hpc-team-a", "hpc-team-b", "cb-accounts", "cb-ledger", "cb-frontend"},
				"attestation_kms_key":         loggingHarness.GetStringOutput("attestation_kms_key"),
			}

			maps.Copy(vars, attestation)

			k8sOpts := k8s.NewKubectlOptions(fmt.Sprintf("connectgateway_%s_%s_%s", clusterProjectId, clusterLocation, clusterName), "", "")

			fleetscope := tft.NewTFBlueprintTest(t,
				tft.WithTFDir(fmt.Sprintf("../../../3-fleetscope/envs/%s", envName)),
				tft.WithVars(vars),
				tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
				tft.WithBackendConfig(backendConfig),
				tft.WithParallelism(3),
			)

			fleetscope.DefineInit(func(assert *assert.Assertions) {
				// install keueue on 3-fleetscope if environment variable INSTALL_KUEUE is true
				if strings.ToLower(os.Getenv("INSTALL_KUEUE")) == "true" {
					// by renaming kueue.tf.example to kueue.tf the module will install kueue
					renameKueueFile(t)
				}
				fleetscope.DefaultInit(assert)
			})

			fleetscope.DefineApply(func(assert *assert.Assertions) {
				fleetscope.DefaultApply(assert)
			})

			fleetscope.DefineVerify(func(assert *assert.Assertions) {
				fleetscope.DefaultVerify(assert)

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
				clusterRegions := testutils.GetBptOutputStrSlice(multitenant, "cluster_regions")
				clusterMembershipIds := testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")
				clusterProjectID := multitenant.GetStringOutput("cluster_project_id")
				clusterProjectNumber := multitenant.GetStringOutput("cluster_project_number")

				membershipNames := []string{}
				for _, region := range clusterRegions {
					membershipName := fmt.Sprintf("projects/%[1]s/locations/%[2]s/memberships/cluster-%[2]s-%[3]s", clusterProjectID, region, envName)
					membershipNames = append(membershipNames, membershipName)
				}
				membershipNamesProjectNumber := []string{}
				for _, region := range clusterRegions {
					membershipName := fmt.Sprintf("projects/%[1]s/locations/%[2]s/memberships/cluster-%[2]s-%[3]s", clusterProjectNumber, region, envName)
					membershipNamesProjectNumber = append(membershipNamesProjectNumber, membershipName)
				}
				// GKE Feature
				for _, feature := range []string{
					"configmanagement",
					"servicemesh",
					"multiclusteringress",
					"multiclusterservicediscovery",
					"policycontroller",
				} {
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
							for _, region := range clusterRegions {
								fleetProjectNumber := gcloud.Runf(t, "projects describe %s", clusterProjectID).Get("projectNumber").String()
								membershipName := fmt.Sprintf("projects/%[1]s/locations/%[2]s/memberships/cluster-%[2]s-%[3]s", fleetProjectNumber, region, envName)
								configmanagementPath := fmt.Sprintf("membershipSpecs.%s.configmanagement", membershipName)

								assert.Equal("unstructured", gkeFeatureOp.Get(configmanagementPath+".configSync.sourceFormat").String(), fmt.Sprintf("Hub Feature %s should have source format equal to unstructured", membershipName))
								assert.Equal("1.22.0", gkeFeatureOp.Get(configmanagementPath+".version").String(), fmt.Sprintf("Hub Feature %s should have source format equal to unstructured", membershipName))
							}
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
								if !strings.Contains(err.Error(), "Error from server (NotFound): rootsyncs.configsync.gke.io \"root-sync\" not found") {
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
				for _, namespaces := range func() []string {
					if hpc {
						return []string{"hpc-team-a", "hpc-team-b"}
					} else {
						return []string{"cb-frontend", "cb-accounts", "cb-ledger", "cymbalshops"}
					}
				}() {
					gkeScopes := fmt.Sprintf("projects/%s/locations/global/scopes/%s-%s", clusterProjectID, namespaces, envName)
					opGKEScopes := gcloud.Runf(t, "container fleet scopes describe projects/%[1]s/locations/global/scopes/%[2]s-%[3]s --project=%[1]s", clusterProjectID, namespaces, envName)
					gkeNamespaces := fmt.Sprintf("projects/%[1]s/locations/global/scopes/%[2]s-%[3]s/namespaces/%[2]s-%[3]s", clusterProjectID, namespaces, envName)
					opNamespaces := gcloud.Runf(t, "container hub scopes namespaces describe projects/%[1]s/locations/global/scopes/%[2]s-%[3]s/namespaces/%[2]s-%[3]s --project=%[1]s", clusterProjectID, namespaces, envName)
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

						t.Logf("source.errorSummary equals {}: %v", jsonOutput.Get("source.errorSummary").String() == "{}")
						t.Logf("sync.errorSummary equals {}: %v", jsonOutput.Get("sync.errorSummary").String() == "{}")
						t.Logf("rendering.errorSummary equals {}: %v", jsonOutput.Get("rendering.errorSummary").String() == "{}")

						return jsonOutput.Get("sync.errorSummary").String() == "{}" && jsonOutput.Get("source.errorSummary").String() == "{}" && jsonOutput.Get("rendering.errorSummary").String() == "{}"
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
			})

			fleetscope.Test()
		})
	}
}

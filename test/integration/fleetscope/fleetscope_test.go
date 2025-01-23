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
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

func retrieveNamespace(t *testing.T) (string, error) {
	cmd := "get ns config-management-system"
	args := strings.Fields(cmd)
	kubectlCmd := shell.Command{
		Command: "kubectl",
		Args:    args,
	}
	return shell.RunCommandAndGetStdOutE(t, kubectlCmd)
}

func retrieveCreds(t *testing.T) (string, error) {
	cmd := "get secret git-creds --namespace=config-management-system --output=yaml"
	args := strings.Fields(cmd)
	kubectlCmd := shell.Command{
		Command: "kubectl",
		Args:    args,
	}
	return shell.RunCommandAndGetStdOutE(t, kubectlCmd)
}

func configureConfigSyncNamespace(t *testing.T) (string, error) {
	_, err := retrieveNamespace(t)
	if err != nil {
		cmd := "create ns config-management-system"
		args := strings.Fields(cmd)
		kubectlCmd := shell.Command{
			Command: "kubectl",
			Args:    args,
		}
		return shell.RunCommandAndGetStdOutE(t, kubectlCmd)
	} else {
		fmt.Println("Namespace already exists")
		return "", err
	}
}

// Create token credentials on config-management-system namespace
func createTokenCredentials(t *testing.T, user string, token string) (string, error) {
	_, err := retrieveCreds(t)
	if err != nil {
		cmd := fmt.Sprintf("create secret generic git-creds --namespace=config-management-system --from-literal=username=%s --from-literal=token=%s", user, token)
		args := strings.Fields(cmd)
		kubectlCmd := shell.Command{
			Command: "kubectl",
			Args:    args,
		}
		return shell.RunCommandAndGetStdOutE(t, kubectlCmd)
	} else {
		// delete existing credentials
		delete_cmd := "delete secret git-creds --namespace=config-management-system"
		delete_cmd_args := strings.Fields(delete_cmd)
		delete_shell_cmd := shell.Command{
			Command: "kubectl",
			Args:    delete_cmd_args,
		}
		_, err = shell.RunCommandAndGetStdOutE(t, delete_shell_cmd)
		if err != nil {
			t.Fatal(err)
		}
		// create new credentials using token
		cmd := fmt.Sprintf("create secret generic git-creds --namespace=config-management-system --from-literal=username=%s --from-literal=token=%s", user, token)
		args := strings.Fields(cmd)
		kubectlCmd := shell.Command{
			Command: "kubectl",
			Args:    args,
		}
		return shell.RunCommandAndGetStdOutE(t, kubectlCmd)
	}

}

// To use config-sync with a gitlab token, the namespace and credentials (token) must exist before running fleetscope code
func applyPreRequisites(t *testing.T, token string) error {
	_, err := configureConfigSyncNamespace(t)
	if err != nil {
		t.Fatal(err)
	}

	_, err = createTokenCredentials(t, "root", token)
	if err != nil {
		t.Fatal(err)
	}

	return err
}

func TestFleetscope(t *testing.T) {
	setup := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup"))
	bootstrap := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../1-bootstrap"),
	)

	backend_bucket := bootstrap.GetStringOutput("state_bucket")
	backendConfig := map[string]interface{}{
		"bucket": backend_bucket,
	}

	gitlabSecretProject := setup.GetStringOutput("gitlab_secret_project")
	gitlabPersonalTokenSecretName := setup.GetStringOutput("gitlab_pat_secret_name")
	token, err := testutils.GetSecretFromSecretManager(t, gitlabPersonalTokenSecretName, gitlabSecretProject)
	if err != nil {
		t.Fatal(err)
	}

	for _, envName := range testutils.EnvNames(t) {
		envName := envName
		t.Run(envName, func(t *testing.T) {
			t.Parallel()
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

			err = applyPreRequisites(t, token)
			if err != nil {
				t.Fatal(err)
			}

			config_sync_url := fmt.Sprintf("%s/root/config-sync-%s.git", setup.GetStringOutput("gitlab_url"), envName)

			vars := map[string]interface{}{
				"remote_state_bucket":        backend_bucket,
				"namespace_ids":              setup.GetJsonOutput("teams").Value().(map[string]interface{}),
				"config_sync_secret_type":    "token",
				"config_sync_repository_url": config_sync_url,
			}

			fleetscope := tft.NewTFBlueprintTest(t,
				tft.WithTFDir(fmt.Sprintf("../../../3-fleetscope/envs/%s", envName)),
				tft.WithVars(vars),
				tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
				tft.WithBackendConfig(backendConfig),
				tft.WithParallelism(1),
			)

			fleetscope.DefineVerify(func(assert *assert.Assertions) {
				fleetscope.DefaultVerify(assert)

				// Multitenant Outputs
				clusterRegions := testutils.GetBptOutputStrSlice(multitenant, "cluster_regions")
				clusterMembershipIds := testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")
				clusterProjectID := multitenant.GetStringOutput("cluster_project_id")
				clusterProjectNumber := multitenant.GetStringOutput("cluster_project_number")

				// Service Account
				// rootReconcilerRoles := []string{"roles/source.reader"}
				// rootReconcilerSa := fmt.Sprintf("root-reconciler@%s.iam.gserviceaccount.com", clusterProjectID)
				// iamReconcilerFilter := fmt.Sprintf("bindings.members:'serviceAccount:%s'", rootReconcilerSa)
				// iamReconcilerCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", iamReconcilerFilter, "--format", "json"})
				// projectPolicyOp := gcloud.Run(t, fmt.Sprintf("projects get-iam-policy %s", clusterProjectID), iamReconcilerCommonArgs).Array()
				// saReconcilerListRoles := testutils.GetResultFieldStrSlice(projectPolicyOp, "bindings.role")
				// assert.Subset(saReconcilerListRoles, rootReconcilerRoles, fmt.Sprintf("service account %s should have \"roles/source.reader\" project level role", rootReconcilerSa))

				// svcRoles := []string{"roles/iam.workloadIdentityUser"}
				// svcSa := fmt.Sprintf("%s.svc.id.goog[config-management-system/root-reconciler]", clusterProjectID)
				// iamSvcFilter := fmt.Sprintf("bindings.members:serviceAccount:'%s'", svcSa)
				// iamSvcCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", iamSvcFilter, "--format", "json"})
				// svcPolicyOp := gcloud.Run(t, fmt.Sprintf("iam service-accounts get-iam-policy %s --project %s", rootReconcilerSa, clusterProjectID), iamSvcCommonArgs).Array()
				// saSvcListRoles := testutils.GetResultFieldStrSlice(svcPolicyOp, "bindings.role")
				// assert.Subset(saSvcListRoles, svcRoles, fmt.Sprintf("service account %s should have \"roles/iam.workloadIdentityUser\" project level role", svcSa))

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

								assert.Equal("gcpserviceaccount", gkeFeatureOp.Get(configmanagementPath+".configSync.git.secretType").String(), fmt.Sprintf("Hub Feature %s should have git secret type equal to gcpserviceaccount", membershipName))
								assert.Equal("unstructured", gkeFeatureOp.Get(configmanagementPath+".configSync.sourceFormat").String(), fmt.Sprintf("Hub Feature %s should have source format equal to unstructured", membershipName))
								assert.Equal("1.19.0", gkeFeatureOp.Get(configmanagementPath+".version").String(), fmt.Sprintf("Hub Feature %s should have source format equal to unstructured", membershipName))
								// assert.Equal(rootReconcilerSa, gkeFeatureOp.Get(configmanagementPath+".configSync.git.gcpServiceAccountEmail").String(), fmt.Sprintf("Hub Feature %s should have git service account type equal to %s", membershipName, rootReconcilerSa))
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
					}
				}

				// GKE Membership binding
				for _, id := range clusterMembershipIds {
					membershipOp := gcloud.Runf(t, "container fleet memberships describe %s", strings.TrimPrefix(id, "//gkehub.googleapis.com/"))
					assert.Equal(fmt.Sprintf("%s.svc.id.goog", clusterProjectID), membershipOp.Get("authority.workloadIdentityPool").String(), fmt.Sprintf("Membership %s workloadIdentityPool should be %s.svc.id.goog", id, clusterProjectID))
				}

				// GKE Scopes and Namespaces
				for _, namespaces := range func() []string {
					if envName == "development" {
						return []string{"cb-frontend", "cb-accounts", "cb-ledger"}
					}
					return []string{"cb-frontend"}
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
							if dataPlaneManagement == "PROVISIONING" || controlPlaneManagement == "PROVISIONING" {
								retry = true
							} else if !(dataPlaneManagement == "ACTIVE" && controlPlaneManagement == "ACTIVE") {
								generalState := result.Get("membershipStates").Get(memberShipName).Get("state.code").String()
								generalDescription := result.Get("membershipStates").Get(memberShipName).Get("state.description").String()
								return false, fmt.Errorf("Service mesh provisioning failed for %s: status='%s' description='%s'", memberShipName, generalState, generalDescription)
							}
						}
						return retry, nil
					}
				}
				utils.Poll(t, pollMeshProvisioning(gkeMeshCommand), 40, 60*time.Second)

			})

			fleetscope.Test()
		})
	}
}

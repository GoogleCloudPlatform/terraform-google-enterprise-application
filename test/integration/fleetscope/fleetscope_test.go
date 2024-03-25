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
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

func TestFleetscope(t *testing.T) {

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
			)

			vars := map[string]interface{}{
				"fleet_project_id":       multitenant.GetStringOutput("fleet_project_id"),
				"cluster_membership_ids": multitenant.GetStringOutputList("cluster_membership_ids"),
			}

			fleetscope := tft.NewTFBlueprintTest(t,
				tft.WithTFDir(fmt.Sprintf("../../../4-fleetscope/envs/%s", envName)),
				tft.WithVars(vars),
				tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
			)

			fleetscope.DefineVerify(func(assert *assert.Assertions) {
				fleetscope.DefaultVerify(assert)

				// Outputs
				fleetProjectID := multitenant.GetStringOutput("fleet_project_id")
				clusterRegions := multitenant.GetStringOutputList("cluster_regions")

				// Service Account
				rootReconcilerSa := fmt.Sprintf("root-reconciler@%s.iam.gserviceaccount.com", fleetProjectID)
				iamReconcilerFilter := fmt.Sprintf("bindings.members:'serviceAccount:%s'", rootReconcilerSa)
				iamReconcilerCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", iamReconcilerFilter, "--format", "json"})
				projectPolicyOp := gcloud.Run(t, fmt.Sprintf("projects get-iam-policy %s", fleetProjectID), iamReconcilerCommonArgs).Array()
				saReconcilerListRoles := testutils.GetResultFieldStrSlice(projectPolicyOp, "bindings.role")
				assert.Subset(saReconcilerListRoles, []string{"roles/source.reader"}, fmt.Sprintf("service account %s should have \"roles/source.reader\" project level role", rootReconcilerSa))

				svcSa := fmt.Sprintf("%s.svc.id.goog[config-management-system/root-reconciler]", fleetProjectID)
				iamSvcFilter := fmt.Sprintf("bindings.members:serviceAccount:'%s'", svcSa)
				iamSvcCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", iamSvcFilter, "--format", "json"})
				svcPolicyOp := gcloud.Run(t, fmt.Sprintf("iam service-accounts get-iam-policy %s --project %s", rootReconcilerSa, fleetProjectID), iamSvcCommonArgs).Array()
				saSvcListRoles := testutils.GetResultFieldStrSlice(svcPolicyOp, "bindings.role")
				assert.Subset(saSvcListRoles, []string{"roles/iam.workloadIdentityUser"}, fmt.Sprintf("service account %s should have \"roles/iam.workloadIdentityUser\" project level role", svcSa))

				// GKE Feature
				for _, feature := range []string{
					"configmanagement",
					"servicemesh",
					"multiclusteringress",
					"multiclusterservicediscovery",
				} {
					gkeFeatureOp := gcloud.Runf(t, "container hub features describe %s --project %s", feature, fleetProjectID)
					assert.Equal("ACTIVE", gkeFeatureOp.Get("resourceState.state").String(), fmt.Sprintf("Hub Feature %s should have resource state equal to ACTIVE", feature))

					if feature == "servicemesh" {
						assert.Equal("MANAGEMENT_AUTOMATIC", gkeFeatureOp.Get("fleetDefaultMemberConfig.mesh.management").String(), fmt.Sprintf("Service Mesh Hub Feature %s should have mesh menagement equal to MANAGEMENT_AUTOMATIC", feature))
					}

					if feature == "multiclusteringress" {
						for _, region := range clusterRegions {
							membershipName := fmt.Sprintf("projects/%[1]s/locations/%[2]s/memberships/cluster-%[2]s-%[3]s", fleetProjectID, region, envName)
							assert.Equal(membershipName, gkeFeatureOp.Get("spec.multiclusteringress.configMembership").String(), fmt.Sprintf("Service Mesh Hub Feature %s should have mesh menagement equal to MANAGEMENT_AUTOMATIC", feature))
						}
					}

					// GKE Feature Membership
					if feature == "configmanagement" {
						for _, region := range clusterRegions {
							fleetProjectNumber := gcloud.Runf(t, "projects describe %s", fleetProjectID).Get("projectNumber").String()
							membershipName := fmt.Sprintf("projects/%[1]s/locations/%[2]s/memberships/cluster-%[2]s-%[3]s", fleetProjectNumber, region, envName)
							configmanagementPath := fmt.Sprintf("membershipSpecs.%s.configmanagement", membershipName)

							assert.Equal("gcpserviceaccount", gkeFeatureOp.Get(configmanagementPath+".configSync.git.secretType").String(), fmt.Sprintf("Hub Feature Membership %s should have git secret type equal to gcpserviceaccount", membershipName))
							assert.Equal("unstructured", gkeFeatureOp.Get(configmanagementPath+".configSync.sourceFormat").String(), fmt.Sprintf("Hub Feature Membership %s should have source format equal to unstructured", membershipName))
							assert.Equal("1.17.2", gkeFeatureOp.Get(configmanagementPath+".version").String(), fmt.Sprintf("Hub Feature Membership %s should have source format equal to unstructured", membershipName))
							assert.Equal(rootReconcilerSa, gkeFeatureOp.Get(configmanagementPath+".configSync.git.gcpServiceAccountEmail").String(), fmt.Sprintf("Hub Feature Membership %s should have git service account type equal to %s", membershipName, rootReconcilerSa))
							assert.True(gkeFeatureOp.Get(configmanagementPath+".policyController.enabled").Bool(), fmt.Sprintf("Hub Feature Membership %s  policy controler should be enabled", membershipName))
							assert.True(gkeFeatureOp.Get(configmanagementPath+".policyController.referentialRulesEnabled").Bool(), fmt.Sprintf("Hub Feature Membership %s  referencial rule should be enabled", membershipName))
							assert.True(gkeFeatureOp.Get(configmanagementPath+".policyController.templateLibraryInstalled").Bool(), fmt.Sprintf("Hub Feature Membership %s  template library should be installed", membershipName))
						}
					}
				}

				// GKE Membership binding
				for _, region := range clusterRegions {
					for _, clustersMembership := range multitenant.GetStringOutputList("cluster_membership_ids") {
						membershipID := gcloud.Runf(t, "container hub memberships describe projects/%[1]s/locations/%[3]s/memberships/cluster-%[3]s-%[2]s --project=%[1]s", fleetProjectID, envName, region)
						opmembershipID := fmt.Sprintf("//gkehub.googleapis.com/%s", membershipID.Get("name").String())
						assert.Equal(clustersMembership, opmembershipID, fmt.Sprintf("membership ID should be %s", clustersMembership))
					}
				}

				// GKE Scopes and Namespaces
				for _, namespaces := range []string{
					"frontend",
					"accounts",
					"transactions",
				} {
					gkeScopes := fmt.Sprintf("projects/%s/locations/global/scopes/%s-%s", fleetProjectID, namespaces, envName)
					opGKEScopes := gcloud.Runf(t, "container fleet scopes describe projects/%[1]s/locations/global/scopes/%[2]s-%[3]s --project=%[1]s", fleetProjectID, namespaces, envName)
					gkeNamespaces := fmt.Sprintf("projects/%[1]s/locations/global/scopes/%[2]s-%[3]s/namespaces/%[2]s-%[3]s", fleetProjectID, namespaces, envName)
					opNamespaces := gcloud.Runf(t, "container hub scopes namespaces describe projects/%[1]s/locations/global/scopes/%[2]s-%[3]s/namespaces/%[2]s-%[3]s --project=%[1]s", fleetProjectID, namespaces, envName)
					assert.Equal(gkeNamespaces, opNamespaces.Get("name").String(), fmt.Sprintf("The GKE Namespace should be %s", gkeNamespaces))
					assert.True(opNamespaces.Exists(), "Namespace %s should exist", gkeNamespaces)
					assert.Equal(gkeScopes, opGKEScopes.Get("name").String(), fmt.Sprintf("The GKE Namespace should be %s", gkeScopes))
					assert.True(opGKEScopes.Exists(), "Namespace %s should exist", gkeScopes)
				}

			})

			fleetscope.Test()
		})
	}
}

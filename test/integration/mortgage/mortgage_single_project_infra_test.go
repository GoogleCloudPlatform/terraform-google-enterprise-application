/**
 * Copyright 2026 Google LLC
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
package mortgage

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/stretchr/testify/assert"
	"github.com/tidwall/gjson"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

// name the function as Test*
func TestStandaloneSingleProjectMortgage(t *testing.T) {

	// initialize Terraform test from the Blueprints test framework
	setupOutput := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup"))

	setupVPCSCOutput := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup/vpcsc"))
	projectID := setupOutput.GetJsonOutput("harness_project_ids").Get("mortgage").String()

	loggingBucketPath := "../../setup/harness/logging_bucket"
	loggingBucket := tft.NewTFBlueprintTest(t, tft.WithTFDir(loggingBucketPath))

	gitlabPath := "../../setup/harness/gitlab"
	gitLab := tft.NewTFBlueprintTest(t, tft.WithTFDir(gitlabPath))

	service_perimeter_mode := setupVPCSCOutput.GetJsonOutput("service_perimeter_mode").String()
	service_perimeter_name := setupVPCSCOutput.GetJsonOutput("service_perimeter_name").String()
	access_level_name := setupVPCSCOutput.GetJsonOutput("access_level_name").String()

	serviceAccount := setupOutput.GetJsonOutput("sa_email").Get("mortgage").String()
	err := os.Setenv("GOOGLE_IMPERSONATE_SERVICE_ACCOUNT", serviceAccount)
	if err != nil {
		t.Fatalf("failed to set GOOGLE_IMPERSONATE_SERVICE_ACCOUNT: %v", err)
	}

	vars := map[string]interface{}{
		"project_id":             projectID,
		"service_perimeter_mode": service_perimeter_mode,
		"service_perimeter_name": service_perimeter_name,
		"teams":                  setupOutput.GetJsonOutput("teams").String(),
		"access_level_name":      access_level_name,
		"logging_bucket":         loggingBucket.GetJsonOutput("logging_bucket").Get("mortgage").String(),
		"bucket_kms_key":         loggingBucket.GetJsonOutput("bucket_kms_key").Get("mortgage").String(),
		"attestation_kms_key":    loggingBucket.GetJsonOutput("attestation_kms_key").Get("mortgage").String(),
		"network_id":             gitLab.GetStringOutput("network_id"),
		"create_nat":             false,
		"enables_network_connection_and_peering_routes": false,
	}

	// wire setup output project_id to example var.project_id
	standaloneSingleProjT := tft.NewTFBlueprintTest(t,
		tft.WithVars(vars),
		tft.WithTFDir("../../../examples/mortgage/standalone-single-project"),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)

	// define and write a custom verifier for this test case call the default verify for confirming no additional changes
	standaloneSingleProjT.DefineVerify(func(assert *assert.Assertions) {
		standaloneSingleProjT.DefaultVerify(assert)
		clusterRegions := testutils.GetBptOutputStrSlice(standaloneSingleProjT, "cluster_regions")
		envName := standaloneSingleProjT.GetStringOutput("env")
		gkeAgentEmail := standaloneSingleProjT.GetStringOutput("gke_agent_sa_email")
		region := clusterRegions[0]

		// artifact registry repository
		arOp := gcloud.Runf(t, "artifacts repositories describe %s --location %s --project %s", "mcp-docker", region, projectID)
		assert.Equal("DOCKER", arOp.Get("format").String(), "MCP Artifact Registry format should be DOCKER")

		// cloud storage bucket for MCP builds
		cloudbuildBucket := standaloneSingleProjT.GetStringOutput("cloudbuild_bucket")
		assert.Equal(fmt.Sprintf("%s-mcp-cloudbuild", projectID), cloudbuildBucket, "MCP Cloud Build bucket name should match convention")
		storageBucketOp := gcloud.Runf(t, "storage buckets describe gs://%s --format=json", cloudbuildBucket)
		assert.True(storageBucketOp.Exists(), fmt.Sprintf("MCP Cloud Build bucket %s should exist", cloudbuildBucket))

		// MCP invoker service account and token creator binding
		invokerEmail := standaloneSingleProjT.GetStringOutput("agent_mcp_invoker_email")
		assert.Equal(fmt.Sprintf("agent-mcp-invoker@%s.iam.gserviceaccount.com", projectID), invokerEmail, "MCP invoker SA email should match expected format")

		invokerIamOp := gcloud.Runf(t, "iam service-accounts get-iam-policy %s --project %s", invokerEmail, projectID)
		assert.Contains(invokerIamOp.String(), gkeAgentEmail, "GKE agent SA should have tokenCreator role on MCP invoker SA")

		// MCP runtime service accounts and Cloud Run services
		mcpServices := []struct {
			Name      string
			AccountID string
		}{
			{Name: "legacy-dms", AccountID: "mcp-legacy-dms"},
			{Name: "corporate-email", AccountID: "mcp-corporate-email"},
			{Name: "income-verification", AccountID: "mcp-income-verification"},
		}

		for _, svc := range mcpServices {
			// cloud run Service
			svcOp := gcloud.Runf(t, "run services describe %s --project %s --region %s", svc.Name, projectID, region)
			assert.Equal(svc.Name, svcOp.Get("metadata.name").String(), fmt.Sprintf("Cloud Run service %s should exist", svc.Name))

			// service account assigned to Cloud Run
			expectedRuntimeSA := fmt.Sprintf("%s@%s.iam.gserviceaccount.com", svc.AccountID, projectID)
			assert.Equal(expectedRuntimeSA, svcOp.Get("spec.template.spec.serviceAccountName").String(), fmt.Sprintf("Cloud Run service %s should use runtime SA %s", svc.Name, expectedRuntimeSA))

			// invoker IAM binding on cloud run service
			svcIamOp := gcloud.Runf(t, "run services get-iam-policy %s --project %s --region %s", svc.Name, projectID, region)
			assert.Contains(svcIamOp.String(), invokerEmail, fmt.Sprintf("Invoker SA should have roles/run.invoker on Cloud Run service %s", svc.Name))
		}

		// MCP Discovered Servers JSON output
		mcpDiscoveredJSON := standaloneSingleProjT.GetStringOutput("mcp_discovered_servers_json")
		assert.NotEmpty(mcpDiscoveredJSON, "mcp_discovered_servers_json output should not be empty")
		parsedJSON := gjson.Parse(mcpDiscoveredJSON)
		assert.Equal(int64(len(mcpServices)), parsedJSON.Get("#").Int(), fmt.Sprintf("mcp_discovered_servers_json should contain %d services", len(mcpServices)))

		// GSA mortgage agent Service Account, IAM roles and Workload Identity binding
		expectedGsaEmail := fmt.Sprintf("gsa-mortgage-agent@%s.iam.gserviceaccount.com", projectID)
		assert.Equal(expectedGsaEmail, gkeAgentEmail, "GSA mortgage agent email should match expected format")

		// project IAM roles for GSA (roles/aiplatform.user, roles/cloudtrace.agent)
		gsaIamFilter := fmt.Sprintf("bindings.members:'serviceAccount:%s'", gkeAgentEmail)
		gsaIamCommonArgs := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", gsaIamFilter, "--format", "json"})
		gsaProjectPolicyOp := gcloud.Run(t, fmt.Sprintf("projects get-iam-policy %s", projectID), gsaIamCommonArgs).Array()
		gsaListRoles := testutils.GetResultFieldStrSlice(gsaProjectPolicyOp, "bindings.role")
		expectedGsaRoles := []string{"roles/aiplatform.user", "roles/cloudtrace.agent"}
		assert.Subset(gsaListRoles, expectedGsaRoles, fmt.Sprintf("Service account %s should have aiplatform.user and cloudtrace.agent roles on project", gkeAgentEmail))

		// Workload Identity User binding on GSA
		gsaIamPolicyOp := gcloud.Runf(t, "iam service-accounts get-iam-policy %s --project %s", gkeAgentEmail, projectID)
		expectedWiMember := fmt.Sprintf("serviceAccount:%s.svc.id.goog[mortgage-agent-%s/mortgage-agent-ksa]", projectID, envName)
		assert.Contains(gsaIamPolicyOp.String(), expectedWiMember, fmt.Sprintf("GSA %s should have Workload Identity binding for %s", gkeAgentEmail, expectedWiMember))
	})

	standaloneSingleProjT.DefineTeardown(func(assert *assert.Assertions) {
		// removes firewall rules created by the service but not being deleted.
		firewallRules := gcloud.Runf(t, "compute firewall-rules list  --project %s --filter=\"csm\"", projectID).Array()
		for i := range firewallRules {
			gcloud.Runf(t, "compute firewall-rules delete %s --project %s -q", firewallRules[i].Get("name"), projectID)
		}
		standaloneSingleProjT.DefaultTeardown(assert)

	})
	// call the test function to execute the integration test
	standaloneSingleProjT.Test()
}

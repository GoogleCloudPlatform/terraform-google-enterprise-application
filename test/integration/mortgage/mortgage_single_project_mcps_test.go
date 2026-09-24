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
	"os"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

// name the function as Test*
func TestMortgageMCPs(t *testing.T) {

	// initialize Terraform test from the Blueprints test framework
	setupOutput := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup"))
	projectID := setupOutput.GetJsonOutput("harness_project_ids").Get("mortgage").String()

	standaloneSingleProject := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../examples/mortgage/standalone-single-project"))
	gke_agent_sa_email := standaloneSingleProject.GetJsonOutput("gke_agent_sa_email").String()

	serviceAccount := setupOutput.GetJsonOutput("sa_email").Get("mortgage").String()
	err := os.Setenv("GOOGLE_IMPERSONATE_SERVICE_ACCOUNT", serviceAccount)
	if err != nil {
		t.Fatalf("failed to set GOOGLE_IMPERSONATE_SERVICE_ACCOUNT: %v", err)
	}

	vars := map[string]interface{}{
		"project_id":         projectID,
		"gke_agent_sa_email": gke_agent_sa_email,
	}

	// wire setup output project_id to example var.project_id
	standaloneSingleProjTMCPs := tft.NewTFBlueprintTest(t,
		tft.WithVars(vars),
		tft.WithTFDir("../../../examples/mortgage/mcp-cloud-run/terraform"),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)

	// call the test function to execute the integration test
	standaloneSingleProjTMCPs.Test()
}

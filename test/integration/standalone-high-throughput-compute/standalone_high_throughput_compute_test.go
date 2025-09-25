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
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

func TestStandaloneHTCExample(t *testing.T) {

	setupOutput := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup/vpcsc"))
	projectID := setupOutput.GetTFSetupStringOutput("seed_project_id")
	service_perimeter_mode := setupOutput.GetStringOutput("service_perimeter_mode")
	service_perimeter_name := setupOutput.GetStringOutput("service_perimeter_name")
	access_level_name := setupOutput.GetStringOutput("access_level_name")

	vars := map[string]interface{}{
		"project_id":             projectID,
		"service_perimeter_mode": service_perimeter_mode,
		"service_perimeter_name": service_perimeter_name,
		"access_level_name":      access_level_name,
	}

	// wire setup output project_id to example var.project_id
	standaloneHTC := tft.NewTFBlueprintTest(t,
		tft.WithVars(vars),
		tft.WithTFDir("../../../examples/high-throughput-compute-standalone"),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		tft.WithParallelism(100),
	)

	standaloneHTC.Test()
}

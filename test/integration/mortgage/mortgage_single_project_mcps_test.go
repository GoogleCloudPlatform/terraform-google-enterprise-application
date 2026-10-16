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

package mortgage

import (
	"fmt"
	"path/filepath"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/stretchr/testify/assert"
)

func TestMortgageMCPs(t *testing.T) {
	standalone := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../examples/mortgage/standalone-single-project"),
	)

	projectID := standalone.GetStringOutput("cluster_project_id")
	regions := testutils.GetBptOutputStrSlice(standalone, "cluster_regions")
	region := regions[0]
	containerRegistry := standalone.GetStringOutput("artifact_registry_url")
	cloudBuildBucket := standalone.GetStringOutput("cloudbuild_bucket")

	mcpSourcePath, err := filepath.Abs("../../../examples/mortgage/6-appsource/mcp-cloud-run")
	if err != nil {
		t.Fatal(err)
	}

	mcpServers := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(mcpSourcePath),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)

	mcpServers.DefineVerify(func(assert *assert.Assertions) {
		t.Logf("Building all MCP images with Cloud Build...")
		cloudBuildConfig := filepath.Join(mcpSourcePath, "cloudbuild.yaml")
		buildCmd := fmt.Sprintf("builds submit %s --config=%s --substitutions=_CONTAINER_REGISTRY=%s --gcs-source-staging-dir=gs://%s/source --project=%s",
			mcpSourcePath,
			cloudBuildConfig,
			containerRegistry,
			cloudBuildBucket,
			projectID,
		)
		gcloud.RunCmd(t, buildCmd)

		mcpServices := []string{
			"legacy-dms",
			"corporate-email",
			"income-verification",
		}

		imageMap := map[string]string{
			"legacy-dms":          fmt.Sprintf("%s/legacy-dms:latest", containerRegistry),
			"corporate-email":     fmt.Sprintf("%s/corporate-email:latest", containerRegistry),
			"income-verification": fmt.Sprintf("%s/income-verification-api:latest", containerRegistry),
		}

		for _, svcName := range mcpServices {
			t.Logf("Updating Cloud Run service %s with image %s...", svcName, imageMap[svcName])
			gcloud.RunCmd(t, fmt.Sprintf("run services update %s --image=%s --project=%s --region=%s", svcName, imageMap[svcName], projectID, region))
		}

		for _, svcName := range mcpServices {
			t.Logf("Checking if Cloud Run service %s is Ready...", svcName)
			svcOp := gcloud.Runf(t, "run services describe %s --project %s --region %s", svcName, projectID, region)
			readyCond := svcOp.Get("status.conditions.#(type==\"Ready\").status").String()
			assert.Equal("True", readyCond, fmt.Sprintf("Cloud Run service %s should be in Ready status", svcName))
		}
	})
	mcpServers.Test()
}

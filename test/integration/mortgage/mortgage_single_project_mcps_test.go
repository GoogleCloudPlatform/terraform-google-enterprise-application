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

	mcpSourcePath, err := filepath.Abs("../../../examples/mortgage/mcp-cloud-run")
	if err != nil {
		t.Fatal(err)
	}

	mcpServers := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(mcpSourcePath),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)

	mcpServers.DefineVerify(func(assert *assert.Assertions) {
		mcpServices := []struct {
			ServiceName string
			SourceDir   string
			ImageName   string
			SAName      string
		}{
			{
				ServiceName: "legacy-dms",
				SourceDir:   "src/legacy-dms",
				ImageName:   "legacy-dms",
				SAName:      "mcp-legacy-dms",
			},
			{
				ServiceName: "corporate-email",
				SourceDir:   "src/corporate-email",
				ImageName:   "corporate-email",
				SAName:      "mcp-corporate-email",
			},
			{
				ServiceName: "income-verification",
				SourceDir:   "src/income-verification-api",
				ImageName:   "income-verification-api",
				SAName:      "mcp-income-verification",
			},
		}

		for _, svc := range mcpServices {
			imageTag := fmt.Sprintf("%s-docker.pkg.dev/%s/mcp-docker/%s", region, projectID, svc.ImageName)
			srcPath := filepath.Join(mcpSourcePath, svc.SourceDir)

			t.Logf("Building image for MCP service %s...", svc.ServiceName)
			buildCmd := fmt.Sprintf("builds submit %s --tag=%s --project=%s", srcPath, imageTag, projectID)
			gcloud.RunCmd(t, buildCmd)

			t.Logf("Updating Cloud Run service image for %s...", svc.ServiceName)
			deployCmd := fmt.Sprintf("run deploy %s "+
				"--image=%s "+
				"--project=%s "+
				"--region=%s "+
				"--service-account=%s@%s.iam.gserviceaccount.com "+
				"--ingress=all "+
				"--set-env-vars=GOOGLE_CLOUD_PROJECT=%s,OTEL_SERVICE_NAME=%s",
				svc.ServiceName,
				imageTag,
				projectID,
				region,
				svc.SAName,
				projectID,
				projectID,
				svc.ServiceName,
			)
			gcloud.RunCmd(t, deployCmd)

			svcOp := gcloud.Runf(t, "run services describe %s --project %s --region %s", svc.ServiceName, projectID, region)
			readyCond := svcOp.Get("status.conditions.#(type==\"Ready\").status").String()
			assert.Equal("True", readyCond, fmt.Sprintf("Cloud Run service %s should be in Ready status", svc.ServiceName))
		}
	})

	mcpServers.Test()
}

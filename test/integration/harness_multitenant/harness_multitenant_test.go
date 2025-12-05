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

package harness_multitenant

import (
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/stretchr/testify/assert"
)

func TestMultitenantHarness(t *testing.T) {
	multitenantPath := "../../setup/harness/multitenant"

	multiTenant := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(multitenantPath),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		tft.WithParallelism(100),
	)
	multiTenant.DefineTeardown(func(assert *assert.Assertions) {
		clusterProjectIDs := multiTenant.GetJsonOutput("network_project_id").Array()
		for _, clusterProjectID := range clusterProjectIDs {
			// removes firewall rules created by the service but not being deleted.
			firewallRules := gcloud.Runf(t, "compute firewall-rules list  --project %s --filter=\"mcsd\"", clusterProjectID.String()).Array()
			for i := range firewallRules {
				gcloud.Runf(t, "compute firewall-rules delete %s --project %s -q", firewallRules[i].Get("name"), clusterProjectID.String())
			}

			endpoints := gcloud.Runf(t, "endpoints services list --project %s", clusterProjectID.String()).Array()
			for i := range endpoints {
				gcloud.Runf(t, "endpoints services delete %s --project %s -q", endpoints[i].Get("name"), clusterProjectID.String())
			}
		}
		multiTenant.DefaultTeardown(assert)

	})
	multiTenant.Test()
}

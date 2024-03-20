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
				//"clusters_ids":           multitenant.GetStringOutputList("clusters_ids"),
				//"environment":            multitenant.GetStringOutput("env"),
			}

			fleetscope := tft.NewTFBlueprintTest(t,
				tft.WithTFDir(fmt.Sprintf("../../../4-fleetscope/envs/%s", envName)),
				tft.WithVars(vars),
				tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
			)

			fleetscope.DefineVerify(func(assert *assert.Assertions) {
				fleetscope.DefaultVerify(assert)

				// GKE Scope
				fleetProjectID := vars["fleet_project_id"].(string)
				clustersMembership := fleetscope.GetStringOutputList("cluster_membership_ids")
				membershipID := gcloud.Runf(t, "container hub memberships describe projects/%[1]s/locations/us-central1/memberships/cluster-us-central1-%[2]s --project=%[1]s", fleetProjectID, envName)
				opmembershipID := fmt.Sprintf("//gkehub.googleapis.com/%s", membershipID.Get("name").String())
				assert.Equal(clustersMembership[0], opmembershipID, fmt.Sprintf("membership ID should be %s", clustersMembership[0]))
			})

			fleetscope.Test()
		})
	}
}

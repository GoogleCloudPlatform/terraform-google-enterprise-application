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

package frontend

import (
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

func TestAppInfraTransactionHistory(t *testing.T) {
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	multitenant_nonprod := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/non-production"))
	multitenant_prod := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/production"))
	appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../3-appfactory/apps/cymbal-bank"))
	projectID := appFactory.GetJsonOutput("app-group").Get("transactionhistory.app_admin_project_id").String()

	vars := map[string]interface{}{
		"project_id":                     projectID,
		"region":                         testutils.GetBptOutputStrSlice(multitenant, "cluster_regions")[0],
		// TODO: Convert to a dynamic array
		"cluster_membership_id_dev":      testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")[0],
		"cluster_membership_ids_nonprod": testutils.GetBptOutputStrSlice(multitenant_nonprod, "cluster_membership_ids"),
		"cluster_membership_ids_prod":    testutils.GetBptOutputStrSlice(multitenant_prod, "cluster_membership_ids"),
		"buckets_force_destroy":          "true",
	}
	frontend := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../5-appinfra/apps/ledger-transactionhistory/envs/shared"),
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)
	frontend.DefineVerify(func(assert *assert.Assertions) {
		frontend.DefaultVerify(assert)
	})
	frontend.Test()
}

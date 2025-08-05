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

package harness_single_project

import (
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

func TestSingleProjectHarness(t *testing.T) {
	singleProjectPath := "../../setup/harness/single_project"

	privateWorkerPoolPath := "../../setup/harness/private_workerpool"
	privateWorkerPool := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(privateWorkerPoolPath),
	)

	loggingBucketPath := "../../setup/harness/logging_bucket"
	loggingBucket := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(loggingBucketPath),
	)

	vars := map[string]interface{}{
		"workerpool_id":       privateWorkerPool.GetStringOutput("workerpool_id"),
		"logging_bucket_name": loggingBucket.GetStringOutput("logging_bucket"),
		"org_id":              loggingBucket.GetTFSetupStringOutput("org_id"),
	}

	singleProject := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(singleProjectPath),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		tft.WithParallelism(100),
		tft.WithVars(vars),
	)

	singleProject.DefineTeardown(func(assert *assert.Assertions) {
		clusterProjectID := singleProject.GetStringOutput("seed_project_id")
		// removes firewall rules created by the service but not being deleted.
		firewallRules := gcloud.Runf(t, "compute firewall-rules list  --project %s --filter=\"mcsd\"", clusterProjectID).Array()
		for i := range firewallRules {
			gcloud.Runf(t, "compute firewall-rules delete %s --project %s -q", firewallRules[i].Get("name"), clusterProjectID)
		}
		singleProject.DefaultTeardown(assert)

	})
	singleProject.Test()
}

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

package harness_gitlab

import (
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

func TestGitLab(t *testing.T) {
	gitLabPath := "../../setup/harness/gitlab"
	privateWorkerPoolPath := "../../setup/harness/private_workerpool"
	privateWorkerPool := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(privateWorkerPoolPath),
	)

	loggingBucketPath := "../../setup/harness/logging_bucket"
	loggingBucket := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(loggingBucketPath),
	)

	vars := map[string]interface{}{
		"network_name":              privateWorkerPool.GetStringOutput("workerpool_network_name"),
		"network_id":                privateWorkerPool.GetStringOutput("workerpool_network_id"),
		"project_id":                privateWorkerPool.GetStringOutput("workerpool_project_id"),
		"logging_kms_crypto_id":     loggingBucket.GetStringOutput("bucket_kms_key"),
		"logging_bucket_name":       loggingBucket.GetStringOutput("logging_bucket"),
		"attestation_kms_crypto_id": loggingBucket.GetStringOutput("attestation_kms_key"),
	}

	gitLab := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(gitLabPath),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		tft.WithVars(vars),
		tft.WithParallelism(100),
	)
	gitLab.Test()

}

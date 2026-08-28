// Copyright 2025 Google LLC
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
	"maps"
	"slices"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

func TestGitLab(t *testing.T) {
	gitLabPath := "../../setup/harness/gitlab"
	loggingBucketPath := "../../setup/harness/logging_bucket"
	loggingBucket := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(loggingBucketPath),
	)

	vars := map[string]interface{}{
		"logging_kms_crypto_id":     loggingBucket.GetJsonOutput("bucket_kms_key").Get("seed").String(),
		"logging_bucket_name":       loggingBucket.GetJsonOutput("logging_bucket").Get("seed").String(),
		"attestation_kms_crypto_id": loggingBucket.GetJsonOutput("attestation_kms_key").Get("seed").String(),
		"harness_project_ids":       slices.Collect(maps.Values(loggingBucket.GetTFSetupJsonOutput("harness_project_ids").Map())),
	}

	gitLab := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(gitLabPath),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		tft.WithVars(vars),
		tft.WithParallelism(100),
	)
	gitLab.Test()

}

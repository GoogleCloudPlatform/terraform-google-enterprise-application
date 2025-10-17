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

package bootstrap

import (
	"fmt"
	"os"
	"os/exec"
	"path"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

func TestBootstrap(t *testing.T) {

	triggerRegion := "us-central1"

	vpcsc := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../setup/vpcsc"),
	)

	privateWorkerPoolPath := "../../setup/harness/private_workerpool"
	privateWorkerPool := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(privateWorkerPoolPath),
	)

	multitenantHarnessPath := "../../setup/harness/multitenant"
	multitenantHarness := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(multitenantHarnessPath),
	)

	loggingHarnessPath := "../../setup/harness/logging_bucket"
	loggingHarness := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(loggingHarnessPath),
	)

	bktPrefix := "bkt"

	vars := map[string]interface{}{
		"bucket_force_destroy":    true,
		"project_id":              vpcsc.GetTFSetupStringOutput("seed_project_id"),
		"access_level_name":       vpcsc.GetStringOutput("access_level_name"),
		"service_perimeter_name":  vpcsc.GetStringOutput("service_perimeter_name"),
		"service_perimeter_mode":  vpcsc.GetStringOutput("service_perimeter_mode"),
		"workerpool_id":           privateWorkerPool.GetStringOutput("workerpool_id"),
		"common_folder_id":        multitenantHarness.GetStringOutput("common_folder_id"),
		"envs":                    multitenantHarness.GetJsonOutput("envs").Map(),
		"logging_bucket":          loggingHarness.GetStringOutput("logging_bucket"),
		"bucket_kms_key":          loggingHarness.GetStringOutput("bucket_kms_key"),
		"attestation_kms_project": loggingHarness.GetStringOutput("project_id"),
		"bucket_prefix":           bktPrefix,
	}

	bootstrap := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../1-bootstrap"),
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		tft.WithParallelism(100),
	)

	bootstrap.DefineApply(
		func(assert *assert.Assertions) {
			bootstrap.DefaultApply(assert)

			// configure options to push state to GCS bucket
			tempOptions := bootstrap.GetTFOptions()
			tempOptions.MigrateState = true
			tempOptions.BackendConfig = map[string]interface{}{
				"bucket": bootstrap.GetStringOutput("state_bucket"),
			}

			// create backend file
			cwd, err := os.Getwd()
			require.NoError(t, err)
			destFile := path.Join(cwd, "../../../1-bootstrap/backend.tf")
			fExists, err2 := testutils.FileExists(destFile)
			require.NoError(t, err2)
			if !fExists {
				srcFile := path.Join(cwd, "../../../1-bootstrap/backend.tf.example")
				_, err3 := exec.Command("cp", srcFile, destFile).CombinedOutput()
				require.NoError(t, err3)
			}

			terraform.Init(t, tempOptions)
		})

	bootstrap.DefineVerify(func(assert *assert.Assertions) {
		bootstrap.DefaultVerify(assert)

		// Outputs
		projectID := vpcsc.GetTFSetupStringOutput("seed_project_id")
		loggingBucket := loggingHarness.GetStringOutput("logging_bucket")
		kmsKey := loggingHarness.GetStringOutput("bucket_kms_key")

		// Buckets
		gcloudArgsBucket := gcloud.WithCommonArgs([]string{"--project", projectID, "--format=json"})
		bucketInfix := []string{
			"mt",
			"af",
			"fs",
		}
		for _, infix := range bucketInfix {
			urlBuildBucket := fmt.Sprintf("https://www.googleapis.com/storage/v1/b/%s-%s-%s-build", bktPrefix, projectID, infix)
			opBuildBucket := gcloud.Run(t, fmt.Sprintf("storage buckets describe gs://%s-%s-%s-build", bktPrefix, projectID, infix), gcloudArgsBucket).Array()
			assert.True(opBuildBucket[0].Exists(), "Bucket %s should exist.", urlBuildBucket)

			urlLogsBucket := fmt.Sprintf("https://www.googleapis.com/storage/v1/b/%s-%s-%s-logs", bktPrefix, projectID, infix)
			opLogsBucket := gcloud.Run(t, fmt.Sprintf("storage buckets describe gs://%s-%s-%s-logs", bktPrefix, projectID, infix), gcloudArgsBucket).Array()
			assert.True(opLogsBucket[0].Exists(), "Bucket %s should exist.", urlLogsBucket)
		}

		urlStateBucket := fmt.Sprintf("https://www.googleapis.com/storage/v1/b/%s-%s-tf-state", bktPrefix, projectID)
		opStateBucket := gcloud.Run(t, fmt.Sprintf("storage buckets describe gs://%s-%s-tf-state", bktPrefix, projectID), gcloudArgsBucket).Array()
		assert.True(opStateBucket[0].Exists(), "Bucket %s should exist.", urlStateBucket)
		assert.Equal(loggingBucket, opStateBucket[0].Get("logging_config.logBucket").String(), fmt.Sprintf("The bucket should have logging bucket %s.", loggingBucket))
		assert.Equal(kmsKey, opStateBucket[0].Get("default_kms_key").String(), fmt.Sprintf("The bucket should have the default kms key %s.", kmsKey))

		urlBuilderLogs := fmt.Sprintf("https://www.googleapis.com/storage/v1/b/%s-cb-tf-builder-logs-%s", bktPrefix, projectID)
		opBuilderLogs := gcloud.Run(t, fmt.Sprintf("storage buckets describe gs://%s-cb-tf-builder-logs-%s", bktPrefix, projectID), gcloudArgsBucket).Array()
		assert.True(opBuilderLogs[0].Exists(), "Bucket %s should exist.", urlBuilderLogs)
		assert.Equal(loggingBucket, opBuilderLogs[0].Get("logging_config.logBucket").String(), fmt.Sprintf("The bucket should have logging bucket %s.", loggingBucket))
		assert.Equal(kmsKey, opBuilderLogs[0].Get("default_kms_key").String(), fmt.Sprintf("The bucket should have the default kms key %s.", kmsKey))

		// Source Repo
		repos := []string{
			"eab-applicationfactory",
			"eab-fleetscope",
			"eab-multitenant",
		}

		// Builds
		for _, repo := range repos {
			for _, filter := range []string{
				fmt.Sprintf("name='%s-apply'", repo),
				fmt.Sprintf("name='%s-plan'", repo),
			} {
				cbOpts := gcloud.WithCommonArgs([]string{"--project", projectID, "--filter", filter, "--format", "json", "--region", triggerRegion})
				cbTriggers := gcloud.Run(t, "beta builds triggers list", cbOpts).Array()
				assert.Equal(1, len(cbTriggers), fmt.Sprintf("cloud builds trigger with filter %s should exist", filter))
			}
		}

		// Service Account
		for _, repo := range repos {
			terraformSAEmail := fmt.Sprintf("tf-cb-%s@%s.iam.gserviceaccount.com", repo, projectID)
			terraformSAName := fmt.Sprintf("projects/%s/serviceAccounts/%s", projectID, terraformSAEmail)
			terraformSA := gcloud.Runf(t, "iam service-accounts describe %s --project %s", terraformSAEmail, projectID)
			saRole := []string{"roles/logging.logWriter"}
			iamFilter := fmt.Sprintf("bindings.members:'serviceAccount:%s'", terraformSAEmail)
			iamOpts := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", iamFilter, "--format", "json"})
			projectPolicy := gcloud.Run(t, fmt.Sprintf("projects get-iam-policy %s", projectID), iamOpts).Array()
			listRoles := testutils.GetResultFieldStrSlice(projectPolicy, "bindings.role")
			assert.Equal(terraformSAName, terraformSA.Get("name").String(), fmt.Sprintf("service account %s should exist", repo))
			assert.Subset(listRoles, saRole, fmt.Sprintf("service account %s should have project level roles", terraformSAEmail))
		}
	})

	bootstrap.DefineTeardown(func(assert *assert.Assertions) {
		// configure options to pull state from GCS bucket
		cwd, err := os.Getwd()
		require.NoError(t, err)
		statePath := path.Join(cwd, "../../../1-bootstrap/local_backend.tfstate")
		tempOptions := bootstrap.GetTFOptions()
		tempOptions.MigrateState = true
		tempOptions.BackendConfig = map[string]interface{}{
			"path": statePath,
		}

		// remove backend file
		backendFile := path.Join(cwd, "../../../1-bootstrap/backend.tf")
		fExists, err2 := testutils.FileExists(backendFile)
		require.NoError(t, err2)
		if fExists {
			_, err3 := exec.Command("rm", backendFile).CombinedOutput()
			require.NoError(t, err3)
		}

		terraform.Init(t, tempOptions)
		bootstrap.DefaultTeardown(assert)
	})

	bootstrap.Test()
}

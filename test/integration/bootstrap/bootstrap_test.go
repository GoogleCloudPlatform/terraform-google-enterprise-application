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
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

// fileExists check if a give file exists
func fileExists(filePath string) (bool, error) {
	_, err := os.Stat(filePath)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}

func TestBootstrap(t *testing.T) {

	vars := map[string]interface{}{
		"bucket_force_destroy": true,
	}

	bootstrap := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../1-bootstrap"),
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)

	bootstrap.DefineApply(
		func(assert *assert.Assertions) {
			bootstrap.DefaultApply(assert)

			// configure options to push state to GCS bucket
			tempOptions := bootstrap.GetTFOptions()
			tempOptions.BackendConfig = map[string]interface{}{
				"bucket": bootstrap.GetStringOutput("state_bucket"),
			}
			tempOptions.MigrateState = true
			// create backend file
			cwd, err := os.Getwd()
			require.NoError(t, err)
			destFile := path.Join(cwd, "../../../0-bootstrap/backend.tf")
			fExists, err2 := fileExists(destFile)
			require.NoError(t, err2)
			if !fExists {
				srcFile := path.Join(cwd, "../../../0-bootstrap/backend.tf.example")
				_, err3 := exec.Command("cp", srcFile, destFile).CombinedOutput()
				require.NoError(t, err3)
			}
			terraform.Init(t, tempOptions)
		})

	bootstrap.DefineVerify(func(assert *assert.Assertions) {
		bootstrap.DefaultVerify(assert)

		// Outputs
		projectID := bootstrap.GetStringOutput("project_id")

		// Buckets
		gcloudArgsBucket := gcloud.WithCommonArgs([]string{"--project", projectID, "--json"})
		bucketInfix := []string{
			"mt",
			"af",
			"fs",
		}
		for _, infix := range bucketInfix {
			urlBuildBucket := fmt.Sprintf("https://www.googleapis.com/storage/v1/b/bkt-%s-%s-build", projectID, infix)
			opBuildBucket := gcloud.Run(t, fmt.Sprintf("storage ls --buckets gs://bkt-%s-%s-build", projectID, infix), gcloudArgsBucket).Array()
			assert.True(opBuildBucket[0].Exists(), "Bucket %s should exist.", urlBuildBucket)
			assert.Equal(urlBuildBucket, opBuildBucket[0].Get("metadata.selfLink").String(), fmt.Sprintf("The bucket name should be %s.", urlBuildBucket))

			urlLogsBucket := fmt.Sprintf("https://www.googleapis.com/storage/v1/b/bkt-%s-%s-logs", projectID, infix)
			opLogsBucket := gcloud.Run(t, fmt.Sprintf("storage ls --buckets gs://bkt-%s-%s-logs", projectID, infix), gcloudArgsBucket).Array()
			assert.True(opLogsBucket[0].Exists(), "Bucket %s should exist.", urlLogsBucket)
			assert.Equal(urlLogsBucket, opLogsBucket[0].Get("metadata.selfLink").String(), fmt.Sprintf("The bucket name should be %s.", urlLogsBucket))
		}

		urlStateBucket := fmt.Sprintf("https://www.googleapis.com/storage/v1/b/bkt-%s-tf-state", projectID)
		opStateBucket := gcloud.Run(t, fmt.Sprintf("storage ls --buckets gs://bkt-%s-tf-state", projectID), gcloudArgsBucket).Array()
		assert.True(opStateBucket[0].Exists(), "Bucket %s should exist.", urlStateBucket)
		assert.Equal(urlStateBucket, opStateBucket[0].Get("metadata.selfLink").String(), fmt.Sprintf("The bucket name should be %s.", urlStateBucket))

		// Source Repo
		repos := []string{
			"eab-applicationfactory",
			"eab-fleetscope",
			"eab-multitenant",
		}

		for _, repo := range repos {
			url := fmt.Sprintf("https://source.developers.google.com/p/%s/r/%s", projectID, repo)
			repoOP := gcloud.Runf(t, "source repos describe %s --project %s", repo, projectID)
			repoSa := fmt.Sprintf("serviceAccount:tf-cb-%s@%s.iam.gserviceaccount.com", repo, projectID)
			repoIamOpts := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", "bindings.role:roles/viewer", "--format", "json"})
			repoIamPolicyOp := gcloud.Run(t, fmt.Sprintf("source repos get-iam-policy %s --project %s", repo, projectID), repoIamOpts).Array()[0]
			listMembers := utils.GetResultStrSlice(repoIamPolicyOp.Get("bindings.members").Array())
			assert.Contains(listMembers, repoSa, fmt.Sprintf("Service Account %s should have role roles/viewer on repo %s", repoSa, repo))
			assert.Equal(url, repoOP.Get("url").String(), "source repo %s should have url %s", repo, url)
		}

		// Builds
		branchesRegex := `^(development|non\\-production|production)$`
		for _, repo := range repos {
			for _, filter := range []string{
				fmt.Sprintf("trigger_template.branch_name='%s' trigger_template.repo_name='%s' AND name='%s-apply'", branchesRegex, repo, repo),
				fmt.Sprintf("trigger_template.branch_name='%s' trigger_template.repo_name='%s' AND name='%s-plan'", branchesRegex, repo, repo),
			} {
				cbOpts := gcloud.WithCommonArgs([]string{"--project", projectID, "--filter", filter, "--format", "json"})
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
		tempOptions.BackendConfig = map[string]interface{}{
			"path": statePath,
		}
		tempOptions.MigrateState = true
		// remove backend file
		backendFile := path.Join(cwd, "../../../1-bootstrap/backend.tf")
		fExists, err2 := fileExists(backendFile)
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

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
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/terraform-example-foundation/test/integration/testutils"
)

func TestBootstrap(t *testing.T) {
	bootstrap := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../1-bootstrap"),
	)

	bootstrap.DefineVerify(func(assert *assert.Assertions) {
		bootstrap.DefaultVerify(assert)

		projectID := bootstrap.GetStringOutput("project_id")
		gcloudArgsBucket := gcloud.WithCommonArgs([]string{"--project", projectID, "--json"})

		//Build bucket
		bucketReposBuild := []string{
			"mt-build",
			"af-build",
			"fs-build",
		}
		for _, bucket := range bucketReposBuild {
			urlBucket := fmt.Sprintf("https://www.googleapis.com/storage/v1/b/bkt-%s-%s", projectID, bucket)
			opBucket := gcloud.Run(t, fmt.Sprintf("storage ls --buckets gs://bkt-%s-%s", projectID, bucket), gcloudArgsBucket).Array()
			assert.Equal(urlBucket, opBucket[0].Get("metadata.selfLink").String(), fmt.Sprintf("The bucket name should be %s.", urlBucket))
			assert.True(opBucket[0].Exists(), "Bucket %s should exist.", urlBucket)
		}

		//Logs buckets
		bucketReposLogs := []string{
			"mt-logs",
			"af-logs",
			"fs-logs",
		}
		for _, bucket := range bucketReposLogs {
			urlBucket := fmt.Sprintf("https://www.googleapis.com/storage/v1/b/bkt-%s-%s", projectID, bucket)
			opBucket := gcloud.Run(t, fmt.Sprintf("storage ls --buckets gs://bkt-%s-%s", projectID, bucket), gcloudArgsBucket).Array()
			assert.Equal(urlBucket, opBucket[0].Get("metadata.selfLink").String(), fmt.Sprintf("The bucket name should be %s.", urlBucket))
			assert.True(opBucket[0].Exists(), "Bucket %s should exist.", urlBucket)
		}

		//state bucket
		bucketRepoState := []string{
			"tf-state",
		}
		for _, bucket := range bucketRepoState {
			urlBucket := fmt.Sprintf("https://www.googleapis.com/storage/v1/b/bkt-%s-%s", projectID, bucket)
			opBucket := gcloud.Run(t, fmt.Sprintf("storage ls --buckets gs://bkt-%s-%s", projectID, bucket), gcloudArgsBucket).Array()
			assert.Equal(urlBucket, opBucket[0].Get("metadata.selfLink").String(), fmt.Sprintf("The bucket name should be %s.", urlBucket))
			assert.True(opBucket[0].Exists(), "Bucket %s should exist.", urlBucket)
		}

		//source repositories
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
			repoIamPolicyOp := gcloud.Run(t, fmt.Sprintf("source repos get-iam-policy %s", repo), repoIamOpts).Array()[0]
			listMembers := utils.GetResultStrSlice(repoIamPolicyOp.Get("bindings.members").Array())
			assert.Contains(listMembers, repoSa, fmt.Sprintf("Service Account %s should have role roles/viewer on repo %s", repoSa, repo))
			assert.Equal(url, repoOP.Get("url").String(), "source repo %s should have url %s", repo, url)
		}

		//cloudbuild_triggers
		triggerRepos := []string{
			"eab-applicationfactory",
			"eab-fleetscope",
			"eab-multitenant",
		}

		branchesRegex := `^(development|non\\-production|production)$`

		for _, triggerRepo := range triggerRepos {
			for _, filter := range []string{
				fmt.Sprintf("trigger_template.branch_name='%s' trigger_template.repo_name='%s' AND name='%s-apply'", branchesRegex, triggerRepo, triggerRepo),
				fmt.Sprintf("trigger_template.branch_name='%s' trigger_template.repo_name='%s' AND name='%s-plan'", branchesRegex, triggerRepo, triggerRepo),
			} {
				cbOpts := gcloud.WithCommonArgs([]string{"--project", projectID, "--filter", filter, "--format", "json"})
				cbTriggers := gcloud.Run(t, "beta builds triggers list", cbOpts).Array()
				assert.Equal(1, len(cbTriggers), fmt.Sprintf("cloud builds trigger with filter %s should exist", filter))
			}
		}

		//service account
		serviceAccounts := []string{
			"tf-cb-eab-fleetscope",
			"tf-cb-eab-applicationfactory",
			"tf-cb-eab-multitenant",
		}
		for _, sa := range serviceAccounts {
			terraformSAEmail := fmt.Sprintf("%s@%s.iam.gserviceaccount.com", sa, projectID)
			terraformSAName := fmt.Sprintf("projects/%s/serviceAccounts/%s", projectID, terraformSAEmail)
			terraformSA := gcloud.Runf(t, "iam service-accounts describe %s --project %s", terraformSAEmail, projectID)
			saRole := []string{"roles/logging.logWriter"}
			iamFilter := fmt.Sprintf("bindings.members:'serviceAccount:%s'", terraformSAEmail)
			iamOpts := gcloud.WithCommonArgs([]string{"--flatten", "bindings", "--filter", iamFilter, "--format", "json"})
			projectPolicy := gcloud.Run(t, fmt.Sprintf("projects get-iam-policy %s", projectID), iamOpts).Array()
			listRoles := testutils.GetResultFieldStrSlice(projectPolicy, "bindings.role")
			assert.Equal(terraformSAName, terraformSA.Get("name").String(), fmt.Sprintf("service account %s should exist", sa))
			assert.Subset(listRoles, saRole, fmt.Sprintf("service account %s should have project level roles", terraformSAEmail))
		}
	})
	bootstrap.Test()
}

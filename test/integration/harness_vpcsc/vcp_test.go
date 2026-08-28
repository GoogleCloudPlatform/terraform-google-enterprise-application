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

package harness_vpcsc

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

func TestVPCSC(t *testing.T) {
	vpcPath := "../../setup/vpcsc"
	temp := tft.NewTFBlueprintTest(t, tft.WithTFDir(vpcPath))

	skipGitlab := os.Getenv("_SKIP_GITLAB") == "true"

	projectNumbers := temp.GetTFSetupJsonOutput("harness_project_numbers").Map()
	serviceAccounts := temp.GetTFSetupJsonOutput("sa_email").Map()
	addAccessLevelMembers := strings.Split(os.Getenv("TF_VAR_access_level_members"), ",")
	protected_projects := []string{}

	orgID := temp.GetTFSetupStringOutput("org_id")
	testutils.CleanOrgACMPolicyID(t, orgID)
	accessContextManagerExists := testutils.GetOrgACMPolicyID(t, orgID) != ""
	if !accessContextManagerExists {
		ret, err := testutils.CreateOrgACMPolicyID(t, orgID)
		if err != nil {
			t.Fatalf("Error creating Access Context Manager. %s", err)
		}
		t.Log(ret)
	}

	accessLevelMembers := []string{"serviceAccount:cloud-build@system.gserviceaccount.com"}
	for i, projectNumber := range projectNumbers {
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:%s@cloudbuild.gserviceaccount.com", projectNumber.String()))
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:%s-compute@developer.gserviceaccount.com", projectNumber.String()))
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:%s@cloudservices.gserviceaccount.com", projectNumber.String()))
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:service-%s@container-engine-robot.iam.gserviceaccount.com", projectNumber.String()))
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:service-%s@compute-system.iam.gserviceaccount.com", projectNumber.String()))
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:service-%s@gcp-sa-artifactregistry.iam.gserviceaccount.com", projectNumber.String()))
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:%s", serviceAccounts[i]))
		protected_projects = append(protected_projects, projectNumber.String())
	}

	if len(addAccessLevelMembers) > 0 {
		accessLevelMembers = append(accessLevelMembers, addAccessLevelMembers...)
	}
	t.Logf("accessLevelMembers: %v", accessLevelMembers)
	vars := map[string]interface{}{
		"access_level_members":           accessLevelMembers,
		"protected_projects":             protected_projects,
		"logging_bucket_project_numbers": protected_projects,
	}
	if !skipGitlab {
		gitLabPath := "../../setup/harness/gitlab"
		gitLab := tft.NewTFBlueprintTest(t, tft.WithTFDir(gitLabPath))

		gitLabProjectNumber := gitLab.GetStringOutput("gitlab_project_number")
		vars["gitlab_project_number"] = gitLabProjectNumber
	}

	vpcsc := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(vpcPath),
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		tft.WithParallelism(100),
	)
	vpcsc.Test()

}

func TestCleanVPCSC(t *testing.T) {
	vpcPath := "../../setup/vpcsc"
	temp := tft.NewTFBlueprintTest(t, tft.WithTFDir(vpcPath))
	orgID := temp.GetTFSetupStringOutput("org_id")
	testutils.CleanOrgACMPolicyID(t, orgID)
	if testutils.GetOrgACMPolicyID(t, orgID) == "" {
		_, err := testutils.CreateOrgACMPolicyID(t, orgID)
		if err != nil {
			t.Logf("Error creating the ACM policy: %s", err)
		}
	}
}

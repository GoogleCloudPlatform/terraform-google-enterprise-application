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
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

func TestVPCSC(t *testing.T) {
	vpcPath := "../../setup/vpcsc"
	temp := tft.NewTFBlueprintTest(t, tft.WithTFDir(vpcPath))

	gitLabPath := "../../setup/harness/gitlab"
	gitLab := tft.NewTFBlueprintTest(t, tft.WithTFDir(gitLabPath))

	gitLabProjectNumber := gitLab.GetStringOutput("gitlab_project_number")

	isSingleProject, err := strconv.ParseBool(temp.GetTFSetupStringOutput("single_project"))
	if err != nil {
		isSingleProject = false
	}
	networkProjectsNumber := []string{}

	if !isSingleProject {
		multitenantPath := "../../setup/harness/multitenant"
		multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir(multitenantPath))
		for _, number := range multitenant.GetJsonOutput("network_project_number").Array() {
			networkProjectsNumber = append(networkProjectsNumber, number.String())
		}
	}

	projectNumber := temp.GetTFSetupStringOutput("seed_project_number")
	serviceAccount := temp.GetTFSetupStringOutput("sa_email")
	addAccessLevelMembers := strings.Split(os.Getenv("TF_VAR_access_level_members"), ",")
	protected_projects := []string{}

	// orgID := temp.GetTFSetupStringOutput("org_id")
	// testutils.CleanOrgACMPolicyID(t, orgID)
	// testutils.CreateOrgACMPolicyID(t, orgID)

	HTC, err := strconv.ParseBool(strings.ToLower(os.Getenv("HTC_EXAMPLE")))
	if err != nil {
		HTC = false
	}

	accessLevelMembers := []string{
		fmt.Sprintf("serviceAccount:%s@cloudbuild.gserviceaccount.com", projectNumber),
		fmt.Sprintf("serviceAccount:%s-compute@developer.gserviceaccount.com", projectNumber),
		fmt.Sprintf("serviceAccount:%s@cloudservices.gserviceaccount.com", projectNumber),
		fmt.Sprintf("serviceAccount:%s", serviceAccount),
		"serviceAccount:cloud-build@system.gserviceaccount.com",
	}
	if isSingleProject {
		protected_projects = append(protected_projects, projectNumber)
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:service-%s@container-engine-robot.iam.gserviceaccount.com", projectNumber))
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:service-%s@compute-system.iam.gserviceaccount.com", projectNumber))
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:service-%s@gcp-sa-artifactregistry.iam.gserviceaccount.com", projectNumber))
	} else if HTC {
		protected_projects = append(protected_projects, projectNumber)
	} else {
		protected_projects = append(protected_projects, networkProjectsNumber...)
	}
	accessLevelMembers = append(accessLevelMembers, addAccessLevelMembers...)
	t.Logf("accessLevelMembers: %v", accessLevelMembers)
	vars := map[string]interface{}{
		"access_level_members":          accessLevelMembers,
		"protected_projects":            protected_projects,
		"logging_bucket_project_number": projectNumber,
		"gitlab_project_number":         gitLabProjectNumber,
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

	branchName := utils.ValFromEnv(t, "TF_VAR_branch_name")
	if strings.Contains(branchName, "force-acm-cleanup") {
		testutils.CleanOrgACMPolicyID(t, orgID)
	}
	if testutils.GetOrgACMPolicyID(t, orgID) == "" {
		_, err := testutils.CreateOrgACMPolicyID(t, orgID)
		if err != nil {
			t.Logf("Error creating the ACM policy: %s", err)
		}
	}
}

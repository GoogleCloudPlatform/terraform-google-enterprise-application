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

package vpcsc

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

func TestVPCSC(t *testing.T) {
	vpcPath := "../../setup/vpcsc"
	temp := tft.NewTFBlueprintTest(t, tft.WithTFDir(vpcPath))
	projectNumber := temp.GetTFSetupStringOutput("project_number")
	networkProjectsNumber := temp.GetTFSetupOutputListVal("network_project_number")
	serviceAccount := temp.GetTFSetupStringOutput("sa_email")
	singleProject, _ := strconv.ParseBool(temp.GetTFSetupStringOutput("single_project"))
	addAccessLevelMembers := strings.Split(os.Getenv("access_level_members"), ",")
	protected_projects := []string{}

	accessLevelMembers := []string{
		fmt.Sprintf("serviceAccount:%s@cloudbuild.gserviceaccount.com", projectNumber),
		fmt.Sprintf("serviceAccount:%s-compute@developer.gserviceaccount.com", projectNumber),
		fmt.Sprintf("serviceAccount:%s@cloudservices.gserviceaccount.com", projectNumber),
		fmt.Sprintf("serviceAccount:%s", serviceAccount),
	}
	if singleProject {
		protected_projects = append(protected_projects, projectNumber)
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:service-%s@container-engine-robot.iam.gserviceaccount.com", projectNumber))
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:service-%s@compute-system.iam.gserviceaccount.com", projectNumber))
		accessLevelMembers = append(accessLevelMembers, fmt.Sprintf("serviceAccount:service-%s@gcp-sa-artifactregistry.iam.gserviceaccount.com", projectNumber))
	} else {
		protected_projects = append(protected_projects, networkProjectsNumber...)
	}
	accessLevelMembers = append(accessLevelMembers, addAccessLevelMembers...)

	vars := map[string]interface{}{
		"access_level_members": accessLevelMembers,
		"protected_projects":   protected_projects,
	}

	vpcsc := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(vpcPath),
		tft.WithVars(vars),
		tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
	)
	vpcsc.Test()

}

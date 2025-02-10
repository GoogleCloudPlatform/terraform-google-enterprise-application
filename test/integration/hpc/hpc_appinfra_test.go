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

package hpc

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

func TestHPCAppInfra(t *testing.T) {
	env_cluster_membership_ids := make(map[string]map[string][]string, 0)

	for _, envName := range testutils.EnvNames(t) {
		env_cluster_membership_ids[envName] = make(map[string][]string, 0)
		multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)))
		env_cluster_membership_ids[envName]["cluster_membership_ids"] = testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")
	}

	bootstrap := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../1-bootstrap"),
	)

	type ServiceInfos struct {
		ApplicationName string
		ProjectID       string
		ServiceName     string
		TeamName        string
	}

	servicesInfoMap := make(map[string]ServiceInfos)
	// region := "us-central1" // TODO: Move to terraform.tfvars?

	for appName, serviceNames := range map[string][]string{"hpc": {"montecarlo"}} {
		appName := appName
		appSourcePath := fmt.Sprintf("../../../examples/%s/5-appinfra/%s", appName, appName)
		appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../4-appfactory/envs/shared"))
		for _, fullServiceName := range serviceNames {

			projectID := appFactory.GetJsonOutput("app-group").Get(fmt.Sprintf("%s\\.%s.app_admin_project_id", appName, fullServiceName)).String()
			servicesInfoMap[fullServiceName] = ServiceInfos{
				ApplicationName: appName,
				ProjectID:       projectID,
				ServiceName:     fullServiceName,
				TeamName:        "hpc",
			}

			remoteState := bootstrap.GetStringOutput("state_bucket")

			backend_bucket := strings.Split(appFactory.GetJsonOutput("app-group").Get(fmt.Sprintf("%s\\.%s.app_cloudbuild_workspace_state_bucket_name", appName, fullServiceName)).String(), "/")
			backendConfig := map[string]interface{}{
				"bucket": backend_bucket[len(backend_bucket)-1],
			}

			infraPath := fmt.Sprintf("%s/%s/envs/development", appSourcePath, fullServiceName)
			t.Run(infraPath, func(t *testing.T) {
				t.Parallel()

				vars := map[string]interface{}{
					"remote_state_bucket": remoteState,
				}

				appService := tft.NewTFBlueprintTest(t,
					tft.WithTFDir(infraPath),
					tft.WithVars(vars),
					tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
					tft.WithBackendConfig(backendConfig),
				)
				appService.DefineVerify(func(assert *assert.Assertions) {
					appService.DefaultVerify(assert)
				})
				appService.Test()
			})
		}
	}
}

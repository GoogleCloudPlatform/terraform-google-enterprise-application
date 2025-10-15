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
	"os"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/stretchr/testify/assert"
)

func renameFleetscopeFile(t *testing.T) {
	tf_file_old := "../../../5-appinfra/modules/hpc-monte-carlo-infra/fleetscope.tf.example"
	tf_file_new := "../../../5-appinfra/modules/hpc-monte-carlo-infra/fleetscope.tf"
	// if file does not exist, create it by renaming
	if _, err := os.Stat(tf_file_new); err != nil {
		err = os.Rename(tf_file_old, tf_file_new)
		if err != nil {
			t.Fatal(err)
		}
	}
}

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

	loggingHarnessPath := "../../setup/harness/logging_bucket"
	loggingHarness := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(loggingHarnessPath),
	)

	type ServiceInfos struct {
		ApplicationName string
		ProjectID       string
		ServiceName     string
		TeamName        string
	}

	servicesInfoMap := make(map[string]ServiceInfos)

	// Apply permissions that the user would apply on 3-fleetscope after 5-appinfra
	renameFleetscopeFile(t)

	for appName, serviceNames := range map[string][]string{
		"hpc": {
			"hpc-team-a",
			"hpc-team-b",
		}} {
		appName := appName
		serviceNames := serviceNames
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
			infraPath := fmt.Sprintf("%s/%s/envs/development", appSourcePath, fullServiceName)
			serviceAccount := strings.Split(appFactory.GetJsonOutput("app-group").Get(fmt.Sprintf("%s\\.%s.app_cloudbuild_workspace_cloudbuild_sa_email", appName, fullServiceName)).String(), "/")
			t.Logf("Setting Service Account %s to be impersonated.", serviceAccount[len(serviceAccount)-1])
			f, err := os.Create(fmt.Sprintf("%s/providers.tf", infraPath))
			if err != nil {
				fmt.Println(err)
				return
			}
			provider := `
provider "google" {
	impersonate_service_account = "%s"
}

provider "google-beta" {
	impersonate_service_account = "%s"
}
			`
			l, err := fmt.Fprintf(f, provider, serviceAccount[len(serviceAccount)-1], serviceAccount[len(serviceAccount)-1])
			fmt.Println(l, "bytes written successfully")
			if err != nil {
				fmt.Println(err)
				err = f.Close()
				if err != nil {
					t.Fatalf("failed to close file: %v", err)
				}
				return
			}

			backend_bucket := strings.Split(appFactory.GetJsonOutput("app-group").Get(fmt.Sprintf("%s\\.%s.app_cloudbuild_workspace_state_bucket_name", appName, fullServiceName)).String(), "/")
			backendConfig := map[string]interface{}{
				"bucket": backend_bucket[len(backend_bucket)-1],
			}

			t.Run(infraPath, func(t *testing.T) {
				t.Parallel()

				vars := map[string]interface{}{
					"remote_state_bucket":  remoteState,
					"bucket_force_destroy": true,
					"logging_bucket":       loggingHarness.GetStringOutput("logging_bucket"),
					"bucket_kms_key":       loggingHarness.GetStringOutput("bucket_kms_key"),
					"bucket_prefix":        "bkt",
				}

				appService := tft.NewTFBlueprintTest(t,
					tft.WithTFDir(infraPath),
					tft.WithVars(vars),
					tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
					tft.WithBackendConfig(backendConfig),
					tft.WithParallelism(100),
				)

				appService.DefineVerify(func(assert *assert.Assertions) {
					appService.DefaultVerify(assert)
				})

				appService.DefineTeardown(func(assert *assert.Assertions) {
					for _, team := range []string{"hpc-team-b"} {
						path := fmt.Sprintf("hpc\\.%s.app_infra_project_ids.development", team)
						infraProjectID := appFactory.GetJsonOutput("app-group").Get(path).String()
						zone := "us-central1-a"
						instances := gcloud.Runf(t, "workbench instances list --location=%s --project=%s", zone, infraProjectID).Array()
						for _, instance := range instances {
							name := instance.Get("name")
							gcloud.Runf(t, "workbench instances delete %s --location=%s --project=%s", name, zone, infraProjectID)
						}
					}

					appService.DefaultTeardown(assert)
				})
				appService.Test()
			})
		}
	}
}

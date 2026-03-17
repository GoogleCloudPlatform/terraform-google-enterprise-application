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

package htc_test

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/stretchr/testify/assert"
)

func TestHTCAppInfra(t *testing.T) {
	env_cluster_membership_ids := make(map[string]map[string][]string, 0)

	bootstrap := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../1-bootstrap"),
	)

	multitenantHarnessPath := "../../setup/harness/multitenant"
	multitenantHarness := tft.NewTFBlueprintTest(t,
		tft.WithTFDir(multitenantHarnessPath),
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

	appName := "htc"
	vpcsc := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../setup/vpcsc"),
	)

	appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../4-appfactory/envs/shared"))
	appSourcePath := fmt.Sprintf("../../../examples/%s/5-appinfra/%s", appName, appName)

	projectID := appFactory.GetJsonOutput("app-group").Get(fmt.Sprintf("%s\\.%s.app_admin_project_id", appName, appName)).String()
	servicesInfoMap[appName] = ServiceInfos{
		ApplicationName: appName,
		ProjectID:       projectID,
		ServiceName:     appName,
		TeamName:        "htc",
	}

	remoteState := bootstrap.GetStringOutput("state_bucket")

	backend_bucket := strings.Split(appFactory.GetJsonOutput("app-group").Get(fmt.Sprintf("%s\\.%s.app_cloudbuild_workspace_state_bucket_name", appName, appName)).String(), "/")
	backendConfig := map[string]interface{}{
		"bucket": backend_bucket[len(backend_bucket)-1],
	}

	envs := []string{
		"shared",
	}
	envs = append(envs, testutils.EnvNames(t)...)
	for _, envName := range envs {
		envName := envName

		env_cluster_membership_ids[envName] = make(map[string][]string, 0)
		multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)))
		env_cluster_membership_ids[envName]["cluster_membership_ids"] = testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")
		infraPath := fmt.Sprintf("%s/envs/%s", appSourcePath, envName)
		serviceAccount := strings.Split(appFactory.GetJsonOutput("app-group").Get(fmt.Sprintf("%s\\.%s.app_cloudbuild_workspace_cloudbuild_sa_email", appName, appName)).String(), "/")
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

		t.Run(infraPath, func(t *testing.T) {
			var vars map[string]interface{}
			if envName == "shared" {
				vars = map[string]interface{}{
					"remote_state_bucket":   remoteState,
					"logging_bucket":        loggingHarness.GetStringOutput("logging_bucket"),
					"bucket_kms_key":        loggingHarness.GetStringOutput("bucket_kms_key"),
					"access_level_name":     vpcsc.GetStringOutput("access_level_name"),
					"attestation_kms_key":   loggingHarness.GetStringOutput("attestation_kms_key"),
					"buckets_force_destroy": "true",
					"environment_names":     testutils.EnvNames(t),
				}
			} else {
				vars = map[string]interface{}{
					"remote_state_bucket": remoteState,
					"team":                "htc",
					"envs":                multitenantHarness.GetJsonOutput("envs").Map(),
				}
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
			appService.Test()
		})
	}
}

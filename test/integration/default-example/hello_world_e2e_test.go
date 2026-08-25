// Copyright 2024-2025 Google LLC
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

package default_example

import (
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/gruntwork-io/terratest/modules/shell"
)

func getLogs(t *testing.T) (string, error) {
	cmd := "logs getting-started --pod-running-timeout=30s"
	args := strings.Fields(cmd)
	kubectlCmd := shell.Command{
		Command: "kubectl",
		Args:    args,
	}
	return shell.RunCommandAndGetStdOutE(t, kubectlCmd)
}

func TestHelloWorldSingleProjectE2E(t *testing.T) {
	for _, envName := range testutils.EnvNames(t) {
		envName := envName
		t.Run(envName, func(t *testing.T) {
			infraSingleProject := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../examples/default-example/standalone-single-project"))
			clusterProjectId := infraSingleProject.GetJsonOutput("cluster_project_id").String()
			clusterLocation := infraSingleProject.GetJsonOutput("cluster_regions").Array()[0].String()
			clusterMembership := infraSingleProject.GetJsonOutput("cluster_membership_ids").Array()[0].String()

			// extract clusterName from fleet membership id
			splitClusterMembership := strings.Split(clusterMembership, "/")
			clusterName := splitClusterMembership[len(splitClusterMembership)-1]

			testutils.ConnectToFleet(t, clusterName, clusterLocation, clusterProjectId)

			pollApplication := func() func() (bool, error) {
				return func() (bool, error) {
					logs, err := getLogs(t)
					if err != nil {
						t.Logf("Pod logs not yet available (%v), will retry.", err)
						return true, nil
					}
					if strings.Contains(logs, "Hello world!") {
						t.Log("Application is running: 'Hello world!' found in logs.")
						return false, nil
					}
					t.Logf("Application starting up, current logs: %s", logs)
					return true, nil
				}
			}
			utils.Poll(t, pollApplication(), 40, 60*time.Second)
		})
	}

}

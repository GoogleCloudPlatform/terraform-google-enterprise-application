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

package helloworld_e2e

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/gruntwork-io/terratest/modules/shell"
)

const (
	sleepBetweenRetries time.Duration = time.Duration(60) * time.Second
	maxRetries          int           = 30
	namespace                         = "cymbalshops-development"
	service                           = "frontend-external"
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

func connectToFleet(t *testing.T, clusterName string, location string, project string) {
	gcloud.Runf(t, "container fleet memberships get-credentials %s --location=%s --project=%s", clusterName, location, project)
}

func TestHelloWorldE2E(t *testing.T) {
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	// retrieve cluster location and fleet membership from 2-multitenant
	clusterProjectId := multitenant.GetJsonOutput("cluster_project_id").String()
	clusterLocation := multitenant.GetJsonOutput("cluster_regions").Array()[0].String()
	clusterMembership := multitenant.GetJsonOutput("cluster_membership_ids").Array()[0].String()

	// extract clusterName from fleet membership id
	splitClusterMembership := strings.Split(clusterMembership, "/")
	clusterName := splitClusterMembership[len(splitClusterMembership)-1]

	connectToFleet(t, clusterName, clusterLocation, clusterProjectId)
	t.Run("hello-world End-to-End Test", func(t *testing.T) {

		logs, err := getLogs(t)
		if err != nil {
			t.Fatal(err)
		}

		fmt.Println(logs)
	})
}

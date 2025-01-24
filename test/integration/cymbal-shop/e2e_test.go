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

package cymbalbank_e2e

import (
	"context"
	"fmt"
	"net/http"
	"net/http/cookiejar"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"

	"github.com/gruntwork-io/terratest/modules/retry"
)

const (
	sleepBetweenRetries time.Duration = time.Duration(60) * time.Second
	maxRetries          int           = 30
	namespace                         = "cymbalshops-development"
	service                           = "frontend-external"
)

func getServiceIpAddress(t *testing.T, serviceName string, namespace string) (string, error) {
	cmd := fmt.Sprintf("get service %s -n %s -o jsonpath='{.status.loadBalancer.ingress[0].ip}'", serviceName, namespace)
	args := strings.Fields(cmd)
	kubectlCmd := shell.Command{
		Command: "kubectl",
		Args:    args,
	}
	return shell.RunCommandAndGetStdOutE(t, kubectlCmd)
}

func TestCymbalShopE2E(t *testing.T) {
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	// retrieve cluster location and fleet membership from 2-multitenant
	clusterProjectId := multitenant.GetJsonOutput("cluster_project_id").String()
	clusterLocation := multitenant.GetJsonOutput("cluster_regions").Array()[0].String()
	clusterMembership := multitenant.GetJsonOutput("cluster_membership_ids").Array()[0].String()

	// extract clusterName from fleet membership id
	splitClusterMembership := strings.Split(clusterMembership, "/")
	clusterName := splitClusterMembership[len(splitClusterMembership)-1]

	testutils.ConnectToFleet(t, clusterName, clusterLocation, clusterProjectId)
	t.Run("Cymbal-Shop End-to-End Test", func(t *testing.T) {
		jar, err := cookiejar.New(nil)
		if err != nil {
			t.Fatal(err)
		}
		client := &http.Client{
			Jar: jar,
		}
		ctx := context.Background()

		ipAddress, err := getServiceIpAddress(t, service, namespace)
		if err != nil {
			t.Fatal(err)
		}

		// Test webserver is avaliable
		heartbeat := func() (string, error) {
			req, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("http://%s", ipAddress), nil)
			if err != nil {
				return "", err
			}
			resp, err := client.Do(req)
			if err != nil {
				return "", err
			}
			if resp.StatusCode != 200 {
				fmt.Println(resp)
				return "", err
			}
			return fmt.Sprint(resp.StatusCode), err
		}
		statusCode, _ := retry.DoWithRetryE(
			t,
			fmt.Sprintf("Checking: %s", ipAddress),
			maxRetries,
			sleepBetweenRetries,
			heartbeat,
		)
		if err != nil {
			t.Fatalf("Error: webserver (%s) not ready after %d attemps, status code: %q",
				ipAddress,
				maxRetries,
				statusCode,
			)
		}
	})
}

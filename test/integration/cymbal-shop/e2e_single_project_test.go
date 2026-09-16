// Copyright 2026 Google LLC
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

package cymbal_shop

import (
	"context"
	"fmt"
	"net/http"
	"net/http/cookiejar"
	"strings"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/gruntwork-io/terratest/modules/retry"
)

func TestAppE2ECymbalShopSingleProject(t *testing.T) {
	infraSingleProject := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../examples/cymbal-shop/standalone-single-project"))
	clusterProjectId := infraSingleProject.GetJsonOutput("cluster_project_id").String()
	clusterLocation := infraSingleProject.GetJsonOutput("cluster_regions").Array()[0].String()
	clusterMembership := infraSingleProject.GetJsonOutput("cluster_membership_ids").Array()[0].String()

	// extract clusterName from fleet membership id
	splitClusterMembership := strings.Split(clusterMembership, "/")
	clusterName := splitClusterMembership[len(splitClusterMembership)-1]

	testutils.ConnectToFleet(t, clusterName, clusterLocation, clusterProjectId)
	t.Run("Cymbal-Shop Single Project End-to-End Test", func(t *testing.T) {
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

		// Test webserver is available
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
			t.Fatalf("Error: webserver (%s) not ready after %d attempts, status code: %q",
				ipAddress,
				maxRetries,
				statusCode,
			)
		}
	})
}

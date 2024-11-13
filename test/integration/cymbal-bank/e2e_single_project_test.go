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
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/gruntwork-io/terratest/modules/retry"
)

func TestAppE2ECymbalBankSingleProject(t *testing.T) {
	// initialize Terraform test from the Blueprints test framework
	setupOutput := tft.NewTFBlueprintTest(t)
	projectID := setupOutput.GetTFSetupStringOutput("project_id_standalone")
	standaloneSingleProj := tft.NewTFBlueprintTest(t, tft.WithVars(map[string]interface{}{"project_id": projectID}), tft.WithTFDir("../../../examples/standalone_single_project"))
	t.Run("End to end tests Single project", func(t *testing.T) {
		jar, err := cookiejar.New(nil)
		if err != nil {
			t.Fatal(err)
		}
		client := &http.Client{
			Jar: jar,
		}
		ctx := context.Background()
		ipAddress := standaloneSingleProj.GetJsonOutput("app_ip_addresses").Get("cymbal-bank.cb-frontend-ip").String()

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

		resp, err := login(ctx, client, ipAddress)

		// check if the server replied with authentication cookie
		gotToken := false
		for _, cookie := range resp.Request.Cookies() {
			if cookie.Name == "token" {
				gotToken = true
			}
		}

		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

		if !gotToken {
			fmt.Println("Failed Authentication.")
			fmt.Println(resp.Request)
			t.Fatal(err)
		}

		fmt.Printf("Login resp: %v \n", resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

		resp, err = home(ctx, client, ipAddress)
		fmt.Printf("Home resp: %v \n", resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

		resp, err = deposit(ctx, client, ipAddress)
		fmt.Printf("Deposit resp: %v \n", resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

		_, err = checkTransaction(ctx, client, ipAddress, "5,230.00", "DEPOSIT")
		if err != nil {
			t.Fatal(err)
		}
		resp, err = transfer(ctx, client, ipAddress)
		fmt.Printf("Transfer resp: %v \n", resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}
		_, err = checkTransaction(ctx, client, ipAddress, "320.98", "PAYMENT")
		if err != nil {
			t.Fatal(err)
		}
	})
}

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

package llm_model

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/tidwall/gjson"
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

const (
	sleepBetweenRetries time.Duration = time.Duration(60) * time.Second
	maxRetries          int           = 30
)

func TestLLMModelSingleProjectE2E(t *testing.T) {
	setup := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup"))
	for _, envName := range testutils.EnvNames(t) {
		envName := envName
		// retrieve namespaces from test/setup, they will be used to create the specific namespaces with the environment suffix
		setupNamespaces := setup.GetJsonOutput("teams")
		var namespacesSlice []string
		setupNamespaces.ForEach(func(key, value gjson.Result) bool {
			namespacesSlice = append(namespacesSlice, key.String())
			return true // keep iterating
		})

		t.Run(envName, func(t *testing.T) {
			t.Parallel()

			// retrieve cluster location and fleet membership from 2-multitenant
			infraSingleProject := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../examples/llm-model/standalone-single-project"))
			clusterProjectId := infraSingleProject.GetJsonOutput("cluster_project_id").String()
			clusterLocation := infraSingleProject.GetJsonOutput("cluster_regions").Array()[0].String()
			clusterMembership := infraSingleProject.GetJsonOutput("cluster_membership_ids").Array()[0].String()
			namespace := fmt.Sprintf("vllm-model-%s", envName)
			splitClusterMembership := strings.Split(clusterMembership, "/")
			clusterName := splitClusterMembership[len(splitClusterMembership)-1]

			testutils.ConnectToFleet(t, clusterName, clusterLocation, clusterProjectId)
			k8sOpts := k8s.NewKubectlOptions(fmt.Sprintf("connectgateway_%s_%s_%s", clusterProjectId, clusterLocation, clusterName), "", "")

			ipAddress, err := k8s.RunKubectlAndGetOutputE(t, k8sOpts, "get", "gateway/llamma-model-gw", "-o", "jsonpath={.status.addresses[0].value}", "-n", namespace)
			if err != nil {
				t.Fatal(err)
			}

			client := &http.Client{}
			ctx := context.Background()

			// Test webserver is avaliable
			heartbeat := func() (string, error) {
				req, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("http://%s/health", ipAddress), nil)
				if err != nil {
					return "", err
				}
				resp, err := client.Do(req)

				fmt.Println(resp.StatusCode)
				if err != nil {
					return "", err
				}
				if resp.StatusCode != 200 {
					fmt.Println(resp)
					defer func() {
						if err := resp.Body.Close(); err != nil {
							t.Logf("Error closing response body: %v", err)
						}
					}()

					bodyBytes, err := io.ReadAll(resp.Body)
					if err != nil {
						return "", fmt.Errorf("error reading response body: %w", err)
					}
					bodyString := string(bodyBytes)
					return "", fmt.Errorf("Response Body: %s", bodyString)
				}
				return fmt.Sprint(resp.StatusCode), err
			}
			statusCode, err := retry.DoWithRetryE(
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
			type Message struct {
				Role    string `json:"role"`
				Content string `json:"content"`
			}
			type RequestPayload struct {
				Model       string    `json:"model"`
				Messages    []Message `json:"messages"`
				MaxTokens   int       `json:"max_tokens"`
				Temperature float64   `json:"temperature"`
			}

			fmt.Println("Get best pizza.")
			modelURL := fmt.Sprintf("http://%s/v1/chat/completions", ipAddress)
			requestBody := RequestPayload{
				Model: "Qwen/Qwen2.5-7B-Instruct",
				Messages: []Message{
					{
						Role:    "user",
						Content: "What is the best pizza in the world?",
					},
				},
				MaxTokens:   512,
				Temperature: 0.7,
			}

			// 3. Marshal the struct into JSON bytes
			jsonData, err := json.Marshal(requestBody)
			if err != nil {
				fmt.Printf("Error marshalling JSON: %v\n", err)
				return
			}

			// 4. Create the Retryable Closure
			chatCompletionsReady := func() (string, error) {
				ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
				defer cancel()

				req, err := http.NewRequestWithContext(ctx, "POST", modelURL, bytes.NewBuffer(jsonData))
				if err != nil {
					return "", fmt.Errorf("error creating request: %w", err)
				}

				req.Header.Set("Content-Type", "application/json")

				resp, err := client.Do(req)
				if err != nil {
					return "", fmt.Errorf("network error: %w", err)
				}
				defer func() {
					if err := resp.Body.Close(); err != nil {
						t.Logf("Error closing response body: %v", err)
					}
				}()

				bodyBytes, err := io.ReadAll(resp.Body)
				if err != nil {
					return "", fmt.Errorf("error reading response body: %w", err)
				}
				bodyString := string(bodyBytes)

				if resp.StatusCode == 200 {
					return bodyString, nil
				}

				return "", fmt.Errorf("model not ready (status %d): %s", resp.StatusCode, bodyString)
			}

			// 5. Execute the Retry Loop
			responseBody, err := retry.DoWithRetryE(
				t,
				fmt.Sprintf("Waiting for valid LLM response from %s", modelURL),
				maxRetries,
				sleepBetweenRetries,
				chatCompletionsReady,
			)

			if err != nil {
				t.Fatalf("Failed to get chat completion after %d retries. Last error: %v", maxRetries, err)
			}

			fmt.Println("Response Body:", responseBody)
		})
	}

}

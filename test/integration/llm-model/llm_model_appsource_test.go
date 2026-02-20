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

package llm_model

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/git"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/stretchr/testify/assert"
	"github.com/tidwall/gjson"

	"os"

	cp "github.com/otiai10/copy"
)

func TestSourceLLMModel(t *testing.T) {
	gitLabPath := "../../setup/harness/gitlab"
	gitLab := tft.NewTFBlueprintTest(t, tft.WithTFDir(gitLabPath))
	gitUrl := gitLab.GetStringOutput("gitlab_url")
	gitlabPersonalTokenSecretName := gitLab.GetStringOutput("gitlab_pat_secret_name")
	gitlabSecretProject := gitLab.GetStringOutput("gitlab_secret_project")
	token, err := testutils.GetSecretFromSecretManager(t, gitlabPersonalTokenSecretName, gitlabSecretProject)
	if err != nil {
		t.Fatal(err)
	}

	hostNameWithPath := strings.Split(gitUrl, "https://")[1]
	authenticatedUrl := fmt.Sprintf("https://oauth2:%s@%s/root", token, hostNameWithPath)

	env_cluster_membership_ids := make(map[string]map[string][]string, 0)
	clusterProjectID := map[string]string{}

	for _, envName := range testutils.EnvNames(t) {
		env_cluster_membership_ids[envName] = make(map[string][]string, 0)
		multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)))
		env_cluster_membership_ids[envName]["cluster_membership_ids"] = testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")
		clusterProjectID[envName] = multitenant.GetStringOutput("cluster_project_id")
	}

	region := "us-central1" // TODO: Plumb output from appInfra
	appName := "llm-model"
	serviceName := "llamma-model"
	appSourcePath := fmt.Sprintf("../../../examples/%s/6-appsource/", appName)

	appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../4-appfactory/envs/shared"))

	projectID := appFactory.GetJsonOutput("app-group").Get("llm-model\\.llamma-model.app_admin_project_id").String()
	appInfra := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../examples/%s/5-appinfra/%s/%s/envs/shared", appName, appName, serviceName)))
	deployTargets := appInfra.GetJsonOutput("clouddeploy_targets_names")

	t.Run("replace-repo-contents-and-push", func(t *testing.T) {

		appRepo := fmt.Sprintf("%s/eab-%s-%s", authenticatedUrl, appName, serviceName)

		tmpDirApp := t.TempDir()

		vars := map[string]interface{}{
			"project_id":                 projectID,
			"region":                     region,
			"env_cluster_membership_ids": env_cluster_membership_ids,
			"buckets_force_destroy":      "true",
		}

		appsource := tft.NewTFBlueprintTest(t,
			tft.WithTFDir(appSourcePath),
			tft.WithVars(vars),
			tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
		)

		appsource.DefineVerify(func(assert *assert.Assertions) {

			// Push agent app source code
			gitApp := git.NewCmdConfig(t, git.WithDir(tmpDirApp))
			gitAppRun := func(args ...string) {
				_, err := gitApp.RunCmdE(args...)
				if err != nil {
					t.Fatal(err)
				}
			}

			// copy contents from 6-appsource to the cloned repository
			err = cp.Copy(appSourcePath, fmt.Sprintf("%s/", tmpDirApp))
			if err != nil {
				t.Fatal(err)
			}

			datefile, err := os.OpenFile(fmt.Sprintf("%s/date.txt", tmpDirApp), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
			if err != nil {
				t.Fatal(err)
			}
			defer func() {
				if err := datefile.Close(); err != nil {
					t.Errorf("failed to close datefile: %v", err)
				}
			}()

			_, err = datefile.WriteString(time.Now().String() + "\n")
			if err != nil {
				t.Fatal(err)
			}

			gitAppRun("init", tmpDirApp)
			// gitAppRun("config", "credential.https://source.developers.google.com.helper", "gcloud.sh")
			gitAppRun("config", "user.email", "eab-robot@example.com")
			gitAppRun("config", "user.name", "EAB Robot")
			gitAppRun("config", "init.defaultBranch", "main")
			gitAppRun("config", "http.postBuffer", "157286400")
			gitAppRun("checkout", "-b", "main")
			gitAppRun("remote", "add", "google", appRepo)
			gitApp.AddAll()
			gitApp.CommitWithMsg("initial commit", []string{"--allow-empty"})
			gitAppRun("push", "google", "main", "--force")

			lastCommit := gitApp.GetLatestCommit()
			// filter builds triggered based on pushed commit sha
			buildListCmd := fmt.Sprintf("builds list --region=%s --filter substitutions.COMMIT_SHA='%s' --project %s", region, lastCommit, projectID)
			retriesBuildTrigger := 1
			// poll build until complete
			pollCloudBuild := func(cmd string) func() (bool, error) {
				return func() (bool, error) {
					build := gcloud.Runf(t, cmd).Array()
					if len(build) < 1 {
						if retriesBuildTrigger%3 == 0 {
							// force push to trigger build 1 more time
							t.Logf("Force push again to try trigger build for commit %s", lastCommit)
							gitAppRun("push", "google", "main", "--force")
						}
						retriesBuildTrigger++
						return true, nil
					}
					latestWorkflowRunStatus := build[0].Get("status").String()
					switch latestWorkflowRunStatus {
					case "SUCCESS":
						return false, nil
					case "FAILURE":
						logsCmd := fmt.Sprintf("builds log %s --project=%s --region=%s", build[0].Get("id").String(), build[0].Get("projectId").String(), region)
						logs := gcloud.RunCmd(t, logsCmd)
						t.Logf("%s build-log: %s", serviceName, logs)
						return false, errors.New("Build failed.")
					}
					return true, nil
				}
			}
			utils.Poll(t, pollCloudBuild(buildListCmd), 80, 60*time.Second)

			releaseName := ""
			releaseListCmd := fmt.Sprintf("deploy releases list --project=%s --delivery-pipeline=%s --region=%s --filter=name:%s", projectID, serviceName, region, lastCommit[0:7])
			pollRelease := func(cmd string) func() (bool, error) {
				return func() (bool, error) {
					releases := gcloud.Runf(t, releaseListCmd).Array()
					if len(releases) == 0 {
						return true, nil
					}
					releaseName = releases[0].Get("name").String()
					return false, nil
				}
			}
			utils.Poll(t, pollRelease(releaseListCmd), 60, 60*time.Second)

			targetId := deployTargets.Array()[0]
			rolloutListCmd := fmt.Sprintf("deploy rollouts list --project=%s --delivery-pipeline=%s --region=%s --release=%s --filter targetId=%s", projectID, serviceName, region, releaseName, targetId)
			// Poll CD rollouts until rollout is successful
			pollCloudDeploy := func(cmd string) func() (bool, error) {
				return func() (bool, error) {
					rollouts := gcloud.Runf(t, cmd).Array()
					if len(rollouts) < 1 {
						return true, nil
					}
					latestRolloutState := rollouts[0].Get("state").String()
					if latestRolloutState == "SUCCEEDED" {
						t.Logf("Rollout finished successfully %s. \n", rollouts[0].Get("targetId"))
						// if the application has more than one deploy target, promote it
						if len(deployTargets.Array()) > 1 {
							// start promoting for n+1
							for i := 1; i < len(deployTargets.Array()); i++ {
								nextTargetId := deployTargets.Array()[i]
								promoteCmd := fmt.Sprintf("deploy releases promote --release=%s --delivery-pipeline=%s --region=%s --to-target=%s", releaseName, serviceName, region, nextTargetId)
								t.Logf("Promoting release to next target: %s", nextTargetId)
								targetId = nextTargetId
								// Execute the promote command
								gcloud.Runf(t, promoteCmd)
							}
						}
						return false, nil
					} else if slices.Contains([]string{"IN_PROGRESS", "PENDING_RELEASE"}, latestRolloutState) {
						t.Logf("Rollout in progress %s. \n", rollouts[0].Get("targetId"))
						return true, nil
					} else {
						logsCmd := fmt.Sprintf("builds log %s", rollouts[0].Get("deployingBuild").String())
						logs := gcloud.Runf(t, logsCmd).String()
						t.Logf("%s build-log: %s", serviceName, logs)
						return false, fmt.Errorf("Rollout %s.", latestRolloutState)
					}
				}
			}
			utils.Poll(t, pollCloudDeploy(rolloutListCmd), 60, 60*time.Second)
		})
		appsource.Test()
	})
}

func TestE2ELLMModel(t *testing.T) {
	const (
		sleepBetweenRetries time.Duration = time.Duration(60) * time.Second
		maxRetries          int           = 30
	)
	setup := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../setup"))
	bootstrap := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../../1-bootstrap"),
	)

	err := os.Setenv("GOOGLE_IMPERSONATE_SERVICE_ACCOUNT", bootstrap.GetJsonOutput("cb_service_accounts_emails").Get("fleetscope").String())
	if err != nil {
		t.Fatalf("failed to set GOOGLE_IMPERSONATE_SERVICE_ACCOUNT: %v", err)
	}

	backend_bucket := bootstrap.GetStringOutput("state_bucket")
	backendConfig := map[string]interface{}{
		"bucket": backend_bucket,
	}

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
			multitenant := tft.NewTFBlueprintTest(t,
				tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)),
				tft.WithBackendConfig(backendConfig),
			)

			// retrieve cluster location and fleet membership from 2-multitenant
			clusterProjectId := multitenant.GetJsonOutput("cluster_project_id").String()
			clusterLocation := multitenant.GetJsonOutput("cluster_regions").Array()[0].String()
			clusterMembership := multitenant.GetJsonOutput("cluster_membership_ids").Array()[0].String()
			splitClusterMembership := strings.Split(clusterMembership, "/")
			clusterName := splitClusterMembership[len(splitClusterMembership)-1]
			namespace := fmt.Sprintf("vllm-model-%s", envName)

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

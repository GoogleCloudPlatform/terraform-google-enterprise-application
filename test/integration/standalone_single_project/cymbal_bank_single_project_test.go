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

package standalone_single_project

import (
	"fmt"
	"os"
	"slices"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/git"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/stretchr/testify/assert"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"

	cp "github.com/otiai10/copy"
)

func TestSingleProjectSourceCymbalBank(t *testing.T) {

	env_cluster_membership_ids := make(map[string]map[string][]string, 0)
	// initialize Terraform test from the Blueprints test framework
	setupOutput := tft.NewTFBlueprintTest(t)
	projectID := setupOutput.GetTFSetupStringOutput("project_id")
	gitUrl := setupOutput.GetTFSetupStringOutput("gitlab_url")
	gitlabPersonalTokenSecretName := setupOutput.GetTFSetupStringOutput("gitlab_pat_secret_name")
	gitlabSecretProject := setupOutput.GetTFSetupStringOutput("gitlab_secret_project")

	singleProjectType := os.Getenv("single_project_example_type")
	token, err := testutils.GetSecretFromSecretManager(t, gitlabPersonalTokenSecretName, gitlabSecretProject)
	if err != nil {
		t.Fatal(err)
	}

	hostNameWithPath := strings.Split(gitUrl, "https://")[1]
	authenticatedUrl := fmt.Sprintf("https://oauth2:%s@%s/root", token, hostNameWithPath)

	standaloneSingleProj := tft.NewTFBlueprintTest(t, tft.WithVars(map[string]interface{}{"project_id": projectID}), tft.WithTFDir("../../../examples/standalone_single_project"))

	if singleProjectType == "CONFIDENTIAL_NODES" {
		standaloneSingleProj = tft.NewTFBlueprintTest(t, tft.WithVars(map[string]interface{}{"project_id": projectID}), tft.WithTFDir("../../../examples/standalone_single_project_confidential_nodes"))
	}

	envName := standaloneSingleProj.GetStringOutput("env")
	env_cluster_membership_ids[envName] = make(map[string][]string, 0)
	env_cluster_membership_ids[envName]["cluster_membership_ids"] = testutils.GetBptOutputStrSlice(standaloneSingleProj, "cluster_membership_ids")
	deployTargets := standaloneSingleProj.GetJsonOutput("clouddeploy_targets_names")

	type ServiceInfos struct {
		ProjectID   string
		ServiceName string
		TeamName    string
	}
	var (
		prefixServiceName string
		suffixServiceName string
		splitServiceName  []string
	)
	region := "us-central1"
	servicesInfoMap := make(map[string]ServiceInfos)
	appName := "cymbal-bank"
	appSourcePath := fmt.Sprintf("../../../examples/%s/6-appsource/%s", appName, appName)
	for _, serviceName := range testutils.ServicesNames[appName] {
		serviceName := serviceName // capture range variable
		splitServiceName = strings.Split(serviceName, "-")
		prefixServiceName = splitServiceName[0]
		suffixServiceName = splitServiceName[len(splitServiceName)-1]
		servicesInfoMap[serviceName] = ServiceInfos{
			ProjectID:   projectID,
			ServiceName: suffixServiceName,
			TeamName:    prefixServiceName,
		}
		servicePath := fmt.Sprintf("%s/%s", appSourcePath, serviceName)
		t.Log(servicePath)
		t.Run(servicePath, func(t *testing.T) {
			t.Parallel()
			vars := map[string]interface{}{
				"project_id":                 servicesInfoMap[serviceName].ProjectID,
				"region":                     region,
				"env_cluster_membership_ids": env_cluster_membership_ids,
				"buckets_force_destroy":      "true",
			}

			appsource := tft.NewTFBlueprintTest(t,
				tft.WithTFDir(servicePath),
				tft.WithVars(vars),
				tft.WithRetryableTerraformErrors(testutils.RetryableTransientErrors, 3, 2*time.Minute),
			)
			mapPath := ""
			if servicesInfoMap[serviceName].TeamName == servicesInfoMap[serviceName].ServiceName {
				mapPath = servicesInfoMap[serviceName].TeamName
			} else {
				mapPath = fmt.Sprintf("%s/%s", servicesInfoMap[serviceName].TeamName, servicesInfoMap[serviceName].ServiceName)
			}
			t.Logf("ServicePath: %s, MapPath: %s", servicePath, mapPath)
			appRepo := fmt.Sprintf("%s/eab-%s-%s", authenticatedUrl, appName, serviceName)
			tmpDirApp := t.TempDir()
			dbFrom := fmt.Sprintf("%s/%s-db/k8s/overlays", appSourcePath, servicesInfoMap[serviceName].TeamName)
			dbTo := fmt.Sprintf("%s/src/%s/%s-db/k8s/overlays", tmpDirApp, servicesInfoMap[serviceName].TeamName, servicesInfoMap[serviceName].TeamName)

			appsource.DefineVerify(func(assert *assert.Assertions) {

				// Push cymbal bank app source code
				gitApp := git.NewCmdConfig(t, git.WithDir(tmpDirApp))
				gitAppRun := func(args ...string) {
					_, err := gitApp.RunCmdE(args...)
					if err != nil {
						t.Fatal(err)
					}
				}

				gitAppRun("clone", "--branch", "v0.6.7", "https://github.com/GoogleCloudPlatform/bank-of-anthos.git", tmpDirApp)
				gitAppRun("config", "user.email", "eab-robot@example.com")
				gitAppRun("config", "user.name", "EAB Robot")
				// gitAppRun("config", "credential.https://source.developers.google.com.helper", "gcloud.sh")
				gitAppRun("config", "init.defaultBranch", "main")
				gitAppRun("config", "http.postBuffer", "157286400")
				gitAppRun("checkout", "-b", "main")
				gitAppRun("remote", "add", "google", appRepo)
				datefile, err := os.OpenFile(fmt.Sprintf("%s/src/%s/date.txt", tmpDirApp, mapPath), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
				if err != nil {
					t.Fatal(err)
				}
				defer datefile.Close()

				_, err = datefile.WriteString(time.Now().String() + "\n")
				if err != nil {
					t.Fatal(err)
				}
				gitAppRun("rm", "-r", "src/components")

				// MapPaths which will get the database overlay
				dbPaths := []string{"accounts/contacts", "ledger/balancereader"}

				// base folder only exists in frontend app
				if mapPath == "frontend" {
					gitAppRun("rm", "-r", fmt.Sprintf("src/%s/k8s", mapPath))
				} else if slices.Contains(dbPaths, mapPath) {
					t.Logf("%s - Copying from %s to %s", servicePath, dbFrom, dbTo)
					err = cp.Copy(dbFrom, dbTo)
					if err != nil {
						t.Fatal(err)
					}
				} else {
					t.Logf("%s - Removing database %s", servicePath, dbTo)
					gitAppRun("rm", "-r", dbTo)
				}
				err = cp.Copy(fmt.Sprintf("%s/components", appSourcePath), fmt.Sprintf("%s/src/components", tmpDirApp))
				if err != nil {
					t.Fatal(err)
				}
				err = cp.Copy(fmt.Sprintf("%s/skaffold.yaml", servicePath), fmt.Sprintf("%s/src/%s/skaffold.yaml", tmpDirApp, mapPath))
				if err != nil {
					t.Fatal(err)
				}
				err = cp.Copy(fmt.Sprintf("%s/k8s", servicePath), fmt.Sprintf("%s/src/%s/k8s", tmpDirApp, mapPath))
				if err != nil {
					t.Fatal(err)
				}

				err = cp.Copy(fmt.Sprintf("%s/k8s", servicePath), fmt.Sprintf("%s/src/%s/k8s", tmpDirApp, mapPath))
				if err != nil {
					t.Fatal(err)
				}

				// Copy test-specific k8s manifests to the frontend development overlay
				if mapPath == "frontend" {
					err = cp.Copy("../appsource/assets/", fmt.Sprintf("%s/src/%s/k8s/overlays/development/", tmpDirApp, mapPath))
					if err != nil {
						t.Fatal(err)
					}
				}

				// override default cloudbuild.yaml to allow workpool specification on application CI build
				cloudBuildPath := fmt.Sprintf("%s/cloudbuild-files/%s/cloudbuild.yaml", appSourcePath, servicesInfoMap[serviceName].TeamName)
				newCloudBuildPath := fmt.Sprintf("%s/src/%s/cloudbuild.yaml", tmpDirApp, servicesInfoMap[serviceName].TeamName)
				t.Logf("(cloudbuild.yaml) Copying from %s -> %s", cloudBuildPath, newCloudBuildPath)
				err = cp.Copy(cloudBuildPath, newCloudBuildPath)
				if err != nil {
					t.Fatal(err)
				}

				err = cp.Copy(fmt.Sprintf("%s/%s", appSourcePath, "other-overlays/e2e.Dockerfile"), fmt.Sprintf("%s/.github/workflows/ui-tests/Dockerfile", tmpDirApp))
				if err != nil {
					t.Fatal(err)
				}

				gitAppRun("add", ".")
				gitApp.CommitWithMsg("initial commit", []string{"--allow-empty"})
				gitAppRun("push", "google", "main", "--force")

				lastCommit := gitApp.GetLatestCommit()
				// filter builds triggered based on pushed commit sha
				buildListCmd := fmt.Sprintf("builds list --region=%s --filter substitutions.COMMIT_SHA='%s' --project %s", region, lastCommit, servicesInfoMap[serviceName].ProjectID)
				retriesBuildTrigger := 1
				// poll build until complete
				pollCloudBuild := func(cmd string) func() (bool, error) {
					return func() (bool, error) {
						build := gcloud.Runf(t, cmd).Array()
						if len(build) < 1 {
							if retriesBuildTrigger%3 == 0 {
								// force push to trigger build again
								t.Logf("Try trigger build again for service %s", serviceName)
								datefile, err := os.OpenFile(fmt.Sprintf("%s/src/%s/date.txt", tmpDirApp, mapPath), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
								if err != nil {
									t.Fatal(err)
								}
								defer datefile.Close()

								_, err = datefile.WriteString(time.Now().String() + "\n")
								if err != nil {
									t.Fatal(err)
								}
								gitAppRun("add", ".")
								gitApp.CommitWithMsg("retries build", []string{"--allow-empty"})
								gitAppRun("push", "google", "main", "--force")
								lastCommit = gitApp.GetLatestCommit()
								t.Logf("New commit for %s is: %s", serviceName, lastCommit)
								buildListCmd = fmt.Sprintf("builds list --region=%s --filter substitutions.COMMIT_SHA='%s' --project %s", region, lastCommit, servicesInfoMap[serviceName].ProjectID)
							}
							retriesBuildTrigger++
							return true, nil
						}
						latestWorkflowRunStatus := build[0].Get("status").String()
						t.Logf("Build found for commit %s: %s \n", lastCommit, build[0].Get("buildTriggerId"))
						if latestWorkflowRunStatus == "SUCCESS" {
							t.Logf("Build finished successfully %s. \n", build[0].Get("buildTriggerId"))
							return false, nil
						} else if latestWorkflowRunStatus == "FAILURE" {
							logsCmd := fmt.Sprintf("builds log %s --project=%s --region=%s", build[0].Get("id").String(), build[0].Get("projectId").String(), region)
							logs := gcloud.Runf(t, logsCmd).String()
							t.Logf("%s ci-build-log: %s", servicesInfoMap[serviceName].ServiceName, logs)
							return false, fmt.Errorf("Build failed %s.", build[0].Get("buildTriggerId"))
						}
						return true, nil
					}
				}
				utils.Poll(t, pollCloudBuild(buildListCmd), 40, 60*time.Second)
				releaseName := ""
				releaseListCmd := fmt.Sprintf("deploy releases list --project=%s --delivery-pipeline=%s --region=%s --filter=name:%s", servicesInfoMap[serviceName].ProjectID, servicesInfoMap[serviceName].ServiceName, region, lastCommit[0:7])
				pollRelease := func(cmd string) func() (bool, error) {
					return func() (bool, error) {
						releases := gcloud.Runf(t, cmd).Array()
						if len(releases) == 0 {
							return true, nil
						}
						releaseName = releases[0].Get("name").String()
						return false, nil
					}
				}
				utils.Poll(t, pollRelease(releaseListCmd), 10, 60*time.Second)

				targetId := deployTargets.Get(servicesInfoMap[serviceName].ServiceName).Array()[0]
				rolloutListCmd := fmt.Sprintf("deploy rollouts list --project=%s --delivery-pipeline=%s --region=%s --release=%s --filter targetId=%s", servicesInfoMap[serviceName].ProjectID, servicesInfoMap[serviceName].ServiceName, region, releaseName, targetId)
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
							return false, nil
						} else if slices.Contains([]string{"IN_PROGRESS", "PENDING_RELEASE"}, latestRolloutState) {
							t.Logf("Rollout in progress %s. \n", rollouts[0].Get("targetId"))
							return true, nil
						} else {
							logsCmd := fmt.Sprintf("builds log %s", rollouts[0].Get("deployingBuild").String())
							logs := gcloud.Runf(t, logsCmd).String()
							t.Logf("%s build-log: %s", servicesInfoMap[serviceName].ServiceName, logs)
							return false, fmt.Errorf("Rollout %s.", latestRolloutState)
						}
					}
				}
				utils.Poll(t, pollCloudDeploy(rolloutListCmd), 40, 60*time.Second)
			})
			appsource.Test()
		})

	}
}

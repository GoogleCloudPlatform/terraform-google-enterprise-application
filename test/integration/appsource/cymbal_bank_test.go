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

package appsource

import (
	"errors"
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

func TestSourceCymbalBank(t *testing.T) {

	env_cluster_membership_ids := make(map[string]map[string][]string, 0)

	for _, envName := range testutils.EnvNames(t) {
		env_cluster_membership_ids[envName] = make(map[string][]string, 0)
		multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)))
		env_cluster_membership_ids[envName]["cluster_membership_ids"] = testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")
	}

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
	region := "us-central1" // TODO: Plumb output from appInfra
	servicesInfoMap := make(map[string]ServiceInfos)

	for appName, serviceNames := range testutils.ServicesNames {
		appName := appName
		appSourcePath := fmt.Sprintf("../../../6-appsource/%s", appName)
		appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../4-appfactory/apps/%s", appName)))
		for _, serviceName := range serviceNames {
			serviceName := serviceName // capture range variable
			splitServiceName = strings.Split(serviceName, "-")
			prefixServiceName = splitServiceName[0]
			suffixServiceName = splitServiceName[len(splitServiceName)-1]
			projectID := appFactory.GetJsonOutput("app-group").Get(fmt.Sprintf("%s\\.%s.app_admin_project_id", appName, suffixServiceName)).String()
			servicesInfoMap[serviceName] = ServiceInfos{
				ProjectID:   projectID,
				ServiceName: suffixServiceName,
				TeamName:    prefixServiceName,
			}
			servicePath := fmt.Sprintf("%s/%s", appSourcePath, serviceName)
			t.Run(servicePath, func(t *testing.T) {
				t.Parallel()
				mapPath := ""
				if servicesInfoMap[serviceName].TeamName == servicesInfoMap[serviceName].ServiceName {
					mapPath = servicesInfoMap[serviceName].TeamName
				} else {
					mapPath = fmt.Sprintf("%s/%s", servicesInfoMap[serviceName].TeamName, servicesInfoMap[serviceName].ServiceName)
				}
				t.Logf("ServicePath: %s, MapPath: %s", servicePath, mapPath)
				appRepo := fmt.Sprintf("https://source.developers.google.com/p/%s/r/eab-%s-%s", servicesInfoMap[serviceName].ProjectID, appName, serviceName)
				tmpDirApp := t.TempDir()
				dbFrom := fmt.Sprintf("%s/%s-db/k8s/overlays/development/%s-db.yaml", appSourcePath, servicesInfoMap[serviceName].TeamName, servicesInfoMap[serviceName].TeamName)
				dbTo := fmt.Sprintf("%s/src/%s/%s-db/k8s/overlays/development/%s-db.yaml", tmpDirApp, servicesInfoMap[serviceName].TeamName, servicesInfoMap[serviceName].TeamName, servicesInfoMap[serviceName].TeamName)

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

				appsource.DefineVerify(func(assert *assert.Assertions) {

					// Push cymbal bank app source code
					gitApp := git.NewCmdConfig(t, git.WithDir(tmpDirApp))
					gitAppRun := func(args ...string) {
						_, err := gitApp.RunCmdE(args...)
						if err != nil {
							t.Fatal(err)
						}
					}

					gitAppRun("clone", "--branch", "v0.6.4", "https://github.com/GoogleCloudPlatform/bank-of-anthos.git", tmpDirApp)
					gitAppRun("config", "user.email", "eab-robot@example.com")
					gitAppRun("config", "user.name", "EAB Robot")
					gitAppRun("config", "credential.https://source.developers.google.com.helper", "gcloud.sh")
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

					if mapPath == "frontend" {
						err = cp.Copy("assets/", fmt.Sprintf("%s/src/%s/k8s/overlays/development/", tmpDirApp, mapPath))
						if err != nil {
							t.Fatal(err)
						}
					}

					gitAppRun("add", ".")
					gitApp.CommitWithMsg("initial commit", []string{"--allow-empty"})
					gitAppRun("push", "--all", "google", "-f")

					lastCommit := gitApp.GetLatestCommit()
					// filter builds triggered based on pushed commit sha
					buildListCmd := fmt.Sprintf("builds list --region=%s --filter substitutions.COMMIT_SHA='%s' --project %s", region, lastCommit, servicesInfoMap[serviceName].ProjectID)
					// poll build until complete
					pollCloudBuild := func(cmd string) func() (bool, error) {
						return func() (bool, error) {
							build := gcloud.Runf(t, cmd).Array()
							if len(build) < 1 {
								return true, nil
							}
							latestWorkflowRunStatus := build[0].Get("status").String()
							if latestWorkflowRunStatus == "SUCCESS" {
								return false, nil
							} else if latestWorkflowRunStatus == "FAILURE" {
								return false, errors.New("Build failed.")
							}
							return true, nil
						}
					}
					utils.Poll(t, pollCloudBuild(buildListCmd), 40, 30*time.Second)
					releaseListCmd := fmt.Sprintf("deploy releases list --project=%s --delivery-pipeline=%s --region=%s --filter=name:%s", servicesInfoMap[serviceName].ProjectID, servicesInfoMap[serviceName].ServiceName, region, lastCommit[0:7])
					releases := gcloud.Runf(t, releaseListCmd).Array()
					if len(releases) == 0 {
						t.Fatal("Failed to find the release.")
					}
					releaseName := releases[0].Get("name")
					targetId := fmt.Sprintf("%s-development", region) //TODO: convert to loop using env_cluster_membership_ids
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
								return false, nil
							} else if slices.Contains([]string{"IN_PROGRESS", "PENDING_RELEASE"}, latestRolloutState) {
								return true, nil
							} else {
								logsCmd := fmt.Sprintf("logging read \"resource.type=build\" --project=%s", servicesInfoMap[serviceName].ProjectID)
								logs := gcloud.Runf(t, logsCmd).Array()
								for _, log := range logs {
									t.Logf("build-log: %s", log.Get("textPayload").String())
								}
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
}

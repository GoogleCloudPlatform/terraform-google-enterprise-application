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

	// TODO: switch to an array based on ENVs
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	multitenant_nonprod := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/non-production"))
	multitenant_prod := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/production"))

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
	region := testutils.GetBptOutputStrSlice(multitenant, "cluster_regions")[0]
	servicesInfoMap := make(map[string]ServiceInfos)

	for appName, serviceNames := range testutils.ServicesNames {
		appName := appName
		appSourcePath := fmt.Sprintf("../../../6-appsource/%s", appName)
		appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir(fmt.Sprintf("../../../3-appfactory/apps/%s", appName)))
		for _, serviceName := range serviceNames {
			serviceName := serviceName // capture range variable
			splitServiceName = strings.Split(serviceName, "-")
			prefixServiceName = splitServiceName[0]
			suffixServiceName = splitServiceName[len(splitServiceName)-1]
			projectID := appFactory.GetJsonOutput("app-group").Get(fmt.Sprintf("%s.app_admin_project_id", suffixServiceName)).String()
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
				appRepo := fmt.Sprintf("https://source.developers.google.com/p/%s/r/eab-%s-%s", servicesInfoMap[serviceName].ProjectID, appName, serviceName)
				tmpDirApp := t.TempDir()
				dbFrom := fmt.Sprintf("%s/%s-db/k8s/overlays/development/%s-db.yaml", appSourcePath, servicesInfoMap[serviceName].TeamName, servicesInfoMap[serviceName].TeamName)
				dbTo := fmt.Sprintf("%s/src/%s/%s-db/k8s/overlays/development/%s-db.yaml", tmpDirApp, servicesInfoMap[serviceName].TeamName, servicesInfoMap[serviceName].TeamName, servicesInfoMap[serviceName].TeamName)
				prodTarget := "dev"

				vars := map[string]interface{}{
					"project_id":                     servicesInfoMap[serviceName].ProjectID,
					"region":                         region,
					"cluster_membership_id_dev":      testutils.GetBptOutputStrSlice(multitenant, "cluster_membership_ids")[0],
					"cluster_membership_ids_nonprod": testutils.GetBptOutputStrSlice(multitenant_nonprod, "cluster_membership_ids"),
					"cluster_membership_ids_prod":    testutils.GetBptOutputStrSlice(multitenant_prod, "cluster_membership_ids"),
					"buckets_force_destroy":          "true",
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
					gitAppRun("config", "--global", "credential.https://source.developers.google.com.helper", "gcloud.sh")
					gitAppRun("config", "--global", "init.defaultBranch", "main")
					gitAppRun("config", "--global", "http.postBuffer", "157286400")
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

					// base folder only exists in frontend app
					if mapPath == "frontend" {
						gitAppRun("rm", "-r", fmt.Sprintf("src/%s/k8s", mapPath))
					} else { // there isn't db for frontend.
						fmt.Printf("%s - Copying from %s to %s", servicePath, dbFrom, dbTo)
						err = cp.Copy(dbFrom, dbTo)
						if err != nil {
							t.Fatal(err)
						}
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
					rolloutListCmd := fmt.Sprintf("deploy rollouts list --project=%s --delivery-pipeline=%s --region=%s --release=%s --filter targetId=%s-%s", servicesInfoMap[serviceName].ProjectID, servicesInfoMap[serviceName].ServiceName, region, releaseName, servicesInfoMap[serviceName].ServiceName, prodTarget)
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

// Copyright 2025 Google LLC
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

package hpc

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/git"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/shell"
)

const AI_ON_GKE_GIT_TAG = "v1.10"

func createKueueResources(t *testing.T, options *k8s.KubectlOptions) (string, error) {
	return k8s.RunKubectlAndGetOutputE(t, options, "apply", "-f", "../../../examples/hpc/6-appsource/manifests/kueue-resources.yaml")
}

func setupClusterToolkitInTmpDirectory(t *testing.T) {
	gitCmd := shell.Command{
		Command: "git",
		Args:    []string{"clone", "https://github.com/GoogleCloudPlatform/cluster-toolkit.git", "/tmp/cluster-toolkit"},
	}
	_, err := shell.RunCommandAndGetStdOutE(t, gitCmd)
	if err != nil {
		fmt.Println("Error cloning repository:", err)
		return
	}

	// build gcluster
	makeCmd := shell.Command{
		Command:    "make",
		Args:       []string{},
		WorkingDir: "/tmp/cluster-toolkit",
	}

	_, err = shell.RunCommandAndGetStdOutE(t, makeCmd)
	if err != nil {
		fmt.Println("Error running make:", err)
		return
	}
}

func deployClusterToolkitBlueprint(t *testing.T, projectID string, clusterName string, clusterProject string, vertexSA string) {
	// Construct the --vars flag
	vars := fmt.Sprintf("project_id=%s,cluster_name=%s,cluster_project=%s,service_account_email=%s", projectID, clusterName, clusterProject, vertexSA)
	cmd := shell.Command{
		WorkingDir: "/workspace/examples/hpc/6-appsource",
		Command:    "/tmp/cluster-toolkit/gcluster",
		Args: []string{
			"deploy",
			"fsi-montecarlo-on-batch.yaml",
			"--vars", vars,
			"--auto-approve",
			"-w",
		},
	}

	_, err := shell.RunCommandAndGetStdOutE(t, cmd)
	if err != nil {
		t.Fatal(err)
	}
}

func getNotebookBucketUrl(t *testing.T) string {
	gclusterPrimaryGroupOutputPath := "/workspace/examples/hpc/6-appsource/montecarlo2/primary"
	cmd := shell.Command{
		Command: "terraform",
		Args: []string{
			fmt.Sprintf("-chdir=%s", gclusterPrimaryGroupOutputPath),
			"output",
			"-raw",
			"gcs_bucket_path_data_bucket",
		},
	}
	output, err := shell.RunCommandAndGetStdOutE(t, cmd)
	if err != nil {
		t.Fatal(err)
	}
	return output
}

func runBatchJobs(t *testing.T) {
	notebookBucketUrl := getNotebookBucketUrl(t)
	gcloud.Runf(t, "storage cp -r %s /tmp", notebookBucketUrl)
	notebookBucketName := strings.TrimPrefix(notebookBucketUrl, "gs://")
	codeDirectory := fmt.Sprintf("/tmp/%s", notebookBucketName)

	// Create a virtual environment
	venvCmd := shell.Command{
		Command:    "python3",
		WorkingDir: codeDirectory,
		Args: []string{
			"-m", "venv", "/tmp/monte-carlo-simulation",
		},
	}
	_, err := shell.RunCommandAndGetStdOutE(t, venvCmd)
	if err != nil {
		t.Fatal(err)
	}

	pipCmd := shell.Command{
		Command:    "/tmp/monte-carlo-simulation/bin/python",
		WorkingDir: codeDirectory,
		Args: []string{
			"-m", "pip", "install",
			"-q",
			"-r",
			"requirements.txt",
		},
	}
	_, err = shell.RunCommandAndGetStdOutE(t, pipCmd)
	if err != nil {
		t.Fatal(err)
	}

	createBatchJobs := shell.Command{
		Command:    "/tmp/monte-carlo-simulation/bin/python",
		WorkingDir: codeDirectory,
		Args: []string{
			"gke_batch.py", "--create_job",
		},
	}
	_, err = shell.RunCommandAndGetStdOutE(t, createBatchJobs)
	if err != nil {
		t.Fatal(err)
	}
}

func runDownloadDataScript(t *testing.T, infraProjectTeamB string) {
	codeDirectory := "/workspace/examples/hpc/6-appsource/helpers"
	bucketPrefix := "bkt"
	stocksBucketName := fmt.Sprintf("%s-%s-stocks-historical-data", bucketPrefix, infraProjectTeamB)

	// Create a virtual environment
	venvCmd := shell.Command{
		Command:    "python3",
		WorkingDir: codeDirectory,
		Args: []string{
			"-m", "venv", "/tmp/download-data",
		},
	}
	_, err := shell.RunCommandAndGetStdOutE(t, venvCmd)
	if err != nil {
		t.Fatal(err)
	}

	pipCmd := shell.Command{
		Command:    "/tmp/download-data/bin/python",
		WorkingDir: codeDirectory,
		Args: []string{
			"-m", "pip", "install",
			"-q",
			"-r",
			"download_data_requirements.txt",
		},
	}
	_, err = shell.RunCommandAndGetStdOutE(t, pipCmd)
	if err != nil {
		t.Fatal(err)
	}

	downloadDataCmd := shell.Command{
		Command:    "/tmp/download-data/bin/python",
		WorkingDir: codeDirectory,
		Args: []string{
			"download_data.py", fmt.Sprintf("--bucket_name=%s", stocksBucketName),
		},
	}
	_, err = shell.RunCommandAndGetStdOutE(t, downloadDataCmd)
	if err != nil {
		t.Fatal(err)
	}
}

func TestHPCMonteCarloE2E(t *testing.T) {
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	// retrieve cluster location and fleet membership from 2-multitenant
	clusterProjectId := multitenant.GetJsonOutput("cluster_project_id").String()
	clusterLocation := multitenant.GetJsonOutput("cluster_regions").Array()[0].String()
	clusterMembership := multitenant.GetJsonOutput("cluster_membership_ids").Array()[0].String()

	appFactory := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../4-appfactory/envs/shared"))
	appInfra := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../examples/hpc/5-appinfra/hpc/hpc-team-b/envs/development"))
	infraProjectTeamB := appFactory.GetJsonOutput("app-group").Get("hpc\\.hpc-team-b.app_infra_project_ids.development").String()
	vertexServiceAccount := appInfra.GetStringOutput("vertex_instance_sa")
	// extract clusterName from fleet membership id
	splitClusterMembership := strings.Split(clusterMembership, "/")
	clusterName := splitClusterMembership[len(splitClusterMembership)-1]

	testutils.ConnectToFleet(t, clusterName, clusterLocation, clusterProjectId)
	k8sOpts := k8s.NewKubectlOptions(fmt.Sprintf("connectgateway_%s_%s_%s", clusterProjectId, clusterLocation, clusterName), "", "")

	t.Run("hpc-monte-carlo-simulation Test", func(t *testing.T) {
		t.Parallel()
		_, err := k8s.RunKubectlAndGetOutputE(t, k8sOpts, "wait", "deploy/kueue-controller-manager", "-n", "kueue-system", "--for=condition=available", "--timeout=5m")
		if err != nil {
			t.Fatal(err)
		}

		_, err = createKueueResources(t, k8sOpts)
		if err != nil {
			t.Fatal(err)
		}

		t.Log("Running 'download_data.py' python script to download historical ticker data and upload to bucket:")
		runDownloadDataScript(t, infraProjectTeamB)

		t.Log("Deploying Cluster Blueprint:")
		setupClusterToolkitInTmpDirectory(t)
		deployClusterToolkitBlueprint(t, infraProjectTeamB, clusterName, clusterProjectId, vertexServiceAccount)

		t.Log("Running Batch Jobs:")
		runBatchJobs(t)

		t.Log("Validating Batch Jobs:")
		for count := 0; count < 15; count++ {
			jobsOutput, err := k8s.RunKubectlAndGetOutputE(t, k8sOpts, "get", "jobs", "-n", "hpc-team-b-development", "-o", "json")
			if err != nil {
				t.Fatal(err)
			}
			if strings.Contains(jobsOutput, "completions: 1000") {
				break
			}
			time.Sleep(1 * time.Minute)
		}

	})

	t.Run("hpc-ai-training Test", func(t *testing.T) {
		t.Parallel()
		_, err := k8s.RunKubectlAndGetOutputE(t, k8sOpts, "wait", "deploy/kueue-controller-manager", "-n", "kueue-system", "--for=condition=available", "--timeout=5m")
		if err != nil {
			t.Fatal(err)
		}

		// Retrieve outputs from 5-appinfra
		bootstrap := tft.NewTFBlueprintTest(t,
			tft.WithTFDir("../../../1-bootstrap"),
		)
		remoteState := bootstrap.GetStringOutput("state_bucket")
		vars := map[string]interface{}{
			"remote_state_bucket":  remoteState,
			"bucket_force_destroy": "true",
		}

		backend_bucket := strings.Split(appFactory.GetJsonOutput("app-group").Get("hpc\\.hpc-team-a.app_cloudbuild_workspace_state_bucket_name").String(), "/")
		backendConfig := map[string]interface{}{
			"bucket": backend_bucket[len(backend_bucket)-1],
		}

		appInfraTeamA := tft.NewTFBlueprintTest(t,
			tft.WithTFDir("../../../examples/hpc/5-appinfra/hpc/hpc-team-a/envs/development"),
			tft.WithVars(vars),
			tft.WithBackendConfig(backendConfig),
		)

		imageURL := appInfraTeamA.GetStringOutput("image_url")

		// configure git to clone ai-on-gke repository
		tmpDirApp := t.TempDir()
		gitApp := git.NewCmdConfig(t, git.WithDir(tmpDirApp))
		gitAppRun := func(args ...string) {
			_, err := gitApp.RunCmdE(args...)
			if err != nil {
				t.Fatal(err)
			}
		}
		gitAppRun("clone", "--branch", AI_ON_GKE_GIT_TAG, "https://github.com/GoogleCloudPlatform/ai-on-gke.git", tmpDirApp)

		manifestDir := "../../../examples/hpc/6-appsource/manifests"
		manifestFile := "ai-training-job.yaml"
		manifestFullPath := fmt.Sprintf("%s/%s", manifestDir, manifestFile)
		// run the kubectl job replacing vars
		err = testutils.ReplacePatternInFile("$IMAGE_URL", imageURL, manifestDir, manifestFile)
		if err != nil {
			t.Fatal(err)
		}

		_, err = k8s.RunKubectlAndGetOutputE(t, k8sOpts, "apply", "-f", manifestFullPath, "-n", "hpc-team-a-development")
		if err != nil {
			t.Fatal(err)
		}
		// validate job finished
		for count := 0; count < 15; count++ {
			jobsOutput, err := k8s.RunKubectlAndGetOutputE(t, k8sOpts, "-n", "hpc-team-a-development", "logs", "jobs/mnist-training-job", "-c", "tensorflow")
			if err != nil {
				t.Log(err)
			}
			if strings.Contains(jobsOutput, "Training finished") {
				break
			}
			time.Sleep(2 * time.Minute)
		}
	})
}

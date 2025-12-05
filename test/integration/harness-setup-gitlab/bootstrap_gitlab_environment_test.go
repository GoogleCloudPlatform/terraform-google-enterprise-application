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

package bootstrap_gitlab

import (
	"fmt"
	"io"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/gruntwork-io/terratest/modules/shell"
	gitlab "gitlab.com/gitlab-org/api/client-go"
)

// connects to a Google Cloud VM instance using SSH and retrieves the logs from the VM's Startup Script service
func readLogsFromVm(t *testing.T, instanceName string, instanceZone string, instanceProject string) (string, error) {
	args := []string{"compute", "ssh", instanceName, fmt.Sprintf("--zone=%s", instanceZone), fmt.Sprintf("--project=%s", instanceProject), "-q", "--command=journalctl -u google-startup-scripts.service -n 20"}
	gcloudCmd := shell.Command{
		Command: "gcloud",
		Args:    args,
	}
	return shell.RunCommandAndGetStdOutE(t, gcloudCmd)
}

func TestValidateStartupScript(t *testing.T) {
	// Retrieve output values from test setup
	setup := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../setup/harness/gitlab"),
	)
	instanceName := setup.GetStringOutput("gitlab_instance_name")
	instanceZone := setup.GetStringOutput("gitlab_instance_zone")
	gitlabSecretProject := setup.GetStringOutput("gitlab_secret_project")
	// Periodically read logs from startup script running on the VM instance
	for count := 0; count < 100; count++ {
		logs, err := readLogsFromVm(t, instanceName, instanceZone, gitlabSecretProject)
		if err != nil {
			t.Fatal(err)
		}

		if strings.Contains(logs, "Finished Google Compute Engine Startup Scripts") {
			if strings.Contains(logs, "exit status 1") {
				t.Fatal("ERROR: Startup Script finished with invalid exit status.")
			}
			break
		}
		time.Sleep(12 * time.Second)
	}
}
func TestBootstrapGitlabVM(t *testing.T) {
	caCert, err := os.ReadFile("/usr/local/share/ca-certificates/gitlab.crt")

	if err != nil {
		t.Fatalf("Failed to read CA certificate: %v", err)
	}

	// Retrieve output values from test setup
	setup := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../setup/harness/gitlab"),
	)

	gitlabSecretProject := setup.GetStringOutput("gitlab_secret_project")
	external_url := setup.GetStringOutput("gitlab_url")
	url := "https://gitlab.example.com"
	serviceDirectory := setup.GetStringOutput("gitlab_service_directory")
	gitlabSecretProjectNumber := setup.GetStringOutput("gitlab_project_number")
	gitlabPersonalTokenSecretName := setup.GetStringOutput("gitlab_pat_secret_name")
	gitlabWebhookSecretId := setup.GetStringOutput("gitlab_webhook_secret_id")
	gitlabTokenSecretId := fmt.Sprintf("projects/%s/secrets/%s", gitlabSecretProjectNumber, gitlabPersonalTokenSecretName)

	token, err := testutils.GetSecretFromSecretManager(t, gitlabPersonalTokenSecretName, gitlabSecretProject)
	if err != nil {
		t.Fatal(err)
	}
	git, err := gitlab.NewClient(token, gitlab.WithBaseURL(external_url))
	if err != nil {
		t.Fatal(err)
	}
	repos := []string{
		// 1-boostrap repositories
		"eab-multitenant",
		"eab-fleetscope",
		"eab-applicationfactory",
		// 4-appfactory repositories
		"balancereader-i-r",
		"contacts-i-r",
		"frontend-i-r",
		"ledgerwriter-i-r",
		"transactionhistory-i-r",
		"userservice-i-r",
		"cymbalshop-i-r",
		"hello-world-i-r",
		"hpc-team-a-i-r",
		"hpc-team-b-i-r",
		"capital-agent-i-r",
		// 5-appinfra repositories
		"eab-cymbal-bank-frontend",
		"eab-cymbal-bank-accounts-contacts",
		"eab-cymbal-bank-accounts-userservice",
		"eab-cymbal-bank-ledger-ledgerwriter",
		"eab-cymbal-bank-ledger-transactionhistory",
		"eab-cymbal-bank-ledger-balancereader",
		"eab-cymbal-shop-cymbalshop",
		"eab-default-example-hello-world",
		"eab-agent-capital-agent",
	}

	for _, envName := range testutils.EnvNames(t) {
		repoConfig := fmt.Sprintf("config-sync-%s", envName)
		repos = append(repos, repoConfig)
	}

	for _, repo := range repos {
		p := &gitlab.CreateProjectOptions{
			Name:                 gitlab.Ptr(repo),
			Description:          gitlab.Ptr("Test Repo"),
			InitializeWithReadme: gitlab.Ptr(true),
			Visibility:           gitlab.Ptr(gitlab.PrivateVisibility),
			DefaultBranch:        gitlab.Ptr("master"),
		}
		project, _, err := git.Projects.CreateProject(p)
		if err != nil {
			t.Error(err)
		} else {
			t.Log(project.WebURL)
			t.Log(project.Name)
		}

	}

	root := "../../.."

	// Replace gitlab.com/user with custom self hosted URL using the root namespace

	replacement := fmt.Sprintf("%s/root", url)
	err = testutils.ReplacePatternInTfVars("https://gitlab.com/user", replacement, root)
	if err != nil {
		t.Fatal(err)
	}

	// Replace https://gitlab.com with custom self hosted URL
	err = testutils.ReplacePatternInTfVars("https://gitlab.com", url, root)
	if err != nil {
		t.Fatal(err)
	}

	// Replace SSL Cert
	err = testutils.ReplacePatternInTfVars("REPLACE_WITH_SSL_CERT\n", string(caCert), root)
	if err != nil {
		t.Fatal(err)
	}

	// Replace Service Directory
	err = testutils.ReplacePatternInTfVars("REPLACE_WITH_SERVICE_DIRECTORY", serviceDirectory, root)
	if err != nil {
		t.Fatal(err)
	}

	// Replace webhook secret id
	err = testutils.ReplacePatternInTfVars("REPLACE_WITH_WEBHOOK_SECRET_ID", gitlabWebhookSecretId, root)
	if err != nil {
		t.Fatal(err)
	}

	// Replace gitlab token secret ids
	err = testutils.ReplacePatternInTfVars("REPLACE_WITH_READ_API_SECRET_ID", gitlabTokenSecretId, root)
	if err != nil {
		t.Fatal(err)
	}

	// Replace secret project_id
	err = testutils.ReplacePatternInTfVars("REPLACE_WITH_SECRET_PROJECT_ID", gitlabSecretProject, root)
	if err != nil {
		t.Fatal(err)
	}

	err = testutils.ReplacePatternInTfVars("REPLACE_WITH_READ_USER_SECRET_ID", gitlabTokenSecretId, root)
	if err != nil {
		t.Fatal(err)
	}

	// Print tfvars to output for debug
	printFiles := []string{
		"../../../1-bootstrap/terraform.tfvars",
		"../../../examples/multitenant-applications/4-appfactory/terraform.tfvars",
		"../../../examples/agent/4-appfactory/terraform.tfvars",
		"../../../examples/agent/5-appinfra/agent/capital-agent/envs/shared/terraform.tfvars",
		"../../../examples/multitenant-applications/5-appinfra/cymbal-bank/accounts-contacts/envs/shared/terraform.tfvars",
		"../../../examples/multitenant-applications/5-appinfra/cymbal-shop/cymbalshop/envs/shared/terraform.tfvars",
	}

	for _, filePath := range printFiles {

		file, err := os.Open(filePath)
		if err != nil {
			t.Fatal(err)
		}
		defer func() {
			if err = file.Close(); err != nil {
				t.Fatal(err)
			}
		}()
		b, err := io.ReadAll(file)
		t.Log(string(b))
	}

	// single project repository replacement

	single_project_roots := []string{"../../../examples/standalone_single_project", "../../../examples/standalone_single_project_confidential_nodes"}

	for _, single_project_root := range single_project_roots {

		// Replace gitlab.com/user with custom self hosted URL using the root namespace
		err = testutils.ReplacePatternInFile("https://gitlab.com/user", replacement, single_project_root, "5-appinfra.tf")
		if err != nil {
			t.Fatal(err)
		}

		// Replace https://gitlab.com with custom self hosted URL
		err = testutils.ReplacePatternInFile("https://gitlab.com", url, single_project_root, "5-appinfra.tf")
		if err != nil {
			t.Fatal(err)
		}

		// Replace https://gitlab.com with custom self hosted URL
		err = testutils.ReplacePatternInFile("https://gitlab.com", url, single_project_root, "3-fleetscope.tf")
		if err != nil {
			t.Fatal(err)
		}

		// Replace gitlab.com with custom self hosted URL
		err = testutils.ReplacePatternInFile("gitlab.com", strings.TrimPrefix(url, "https://"), single_project_root, "0-setup.tf")
		if err != nil {
			t.Fatal(err)
		}

		// Replace webhook secret id
		err = testutils.ReplacePatternInFile("REPLACE_WITH_WEBHOOK_SECRET_ID", gitlabWebhookSecretId, single_project_root, "5-appinfra.tf")
		if err != nil {
			t.Fatal(err)
		}

		// Replace gitlab token secret ids
		err = testutils.ReplacePatternInFile("REPLACE_WITH_READ_API_SECRET_ID", gitlabTokenSecretId, single_project_root, "5-appinfra.tf")
		if err != nil {
			t.Fatal(err)
		}

		err = testutils.ReplacePatternInFile("REPLACE_WITH_READ_USER_SECRET_ID", gitlabTokenSecretId, single_project_root, "5-appinfra.tf")
		if err != nil {
			t.Fatal(err)
		}

		// Replace SSL Cert
		err = testutils.ReplacePatternInFile("REPLACE_WITH_SSL_CERT\n", string(caCert), single_project_root, "5-appinfra.tf")
		if err != nil {
			t.Fatal(err)
		}

		// Replace Service Directory
		err = testutils.ReplacePatternInFile("REPLACE_WITH_SERVICE_DIRECTORY", serviceDirectory, single_project_root, "5-appinfra.tf")
		if err != nil {
			t.Fatal(err)
		}
	}
}

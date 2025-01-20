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
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
	gitlab "gitlab.com/gitlab-org/api/client-go"
)

// connects to a Google Cloud VM instance using SSH and retrieves the logs from the VM's Startup Script service
func readLogsFromVm(t *testing.T, instanceName string, instanceZone string, instanceProject string) (string, error) {
	args := []string{"compute", "ssh", instanceName, fmt.Sprintf("--zone=%s", instanceZone), fmt.Sprintf("--project=%s", instanceProject), "--command=journalctl -u google-startup-scripts.service -n 20"}
	gcloudCmd := shell.Command{
		Command: "gcloud",
		Args:    args,
	}
	return shell.RunCommandAndGetStdOutE(t, gcloudCmd)
}

func TestBootstrapGitlabVM(t *testing.T) {
	// Retrieve output values from test setup
	setup := tft.NewTFBlueprintTest(t,
		tft.WithTFDir("../../setup"),
	)
	url := setup.GetStringOutput("gitlab_url")
	gitlabSecretProject := setup.GetStringOutput("gitlab_secret_project")
	gitlabSecretProjectNumber := setup.GetStringOutput("gitlab_project_number")
	gitlabPersonalTokenSecretName := setup.GetStringOutput("gitlab_pat_secret_name")
	gitlabWebhookSecretId := setup.GetStringOutput("gitlab_webhook_secret_id")
	instanceName := setup.GetStringOutput("gitlab_instance_name")
	instanceZone := setup.GetStringOutput("gitlab_instance_zone")
	gitlabTokenSecretId := fmt.Sprintf("projects/%s/secrets/%s", gitlabSecretProjectNumber, gitlabPersonalTokenSecretName)

	// Periodically read logs from startup script running on the VM instance
	for count := 0; count < 10; count++ {
		logs, err := readLogsFromVm(t, instanceName, instanceZone, gitlabSecretProject)
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(logs, "Finished Google Compute Engine Startup Scripts") {
			break
		}
		time.Sleep(3 * time.Minute)
	}

	token, err := testutils.GetSecretFromSecretManager(t, gitlabPersonalTokenSecretName, gitlabSecretProject)
	if err != nil {
		t.Fatal(err)
	}
	git, err := gitlab.NewClient(token, gitlab.WithBaseURL(url))
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
		// 5-appinfra repositories
		"eab-cymbal-bank-frontend",
		"eab-cymbal-bank-accounts-contacts",
		"eab-cymbal-bank-accounts-userservice",
		"eab-cymbal-bank-ledger-ledgerwriter",
		"eab-cymbal-bank-ledger-transactionhistory",
		"eab-cymbal-bank-ledger-balancereader",
		"eab-cymbal-shop-cymbalshop",
	}

	for _, repo := range repos {
		p := &gitlab.CreateProjectOptions{
			Name:                 gitlab.Ptr(repo),
			Description:          gitlab.Ptr("Test Repo"),
			InitializeWithReadme: gitlab.Ptr(true),
			Visibility:           gitlab.Ptr(gitlab.PrivateVisibility),
		}
		project, _, err := git.Projects.CreateProject(p)
		if err != nil {
			t.Fatal(err)
		}
		t.Log(project.WebURL)
		t.Log(project.Name)
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

	err = testutils.ReplacePatternInTfVars("REPLACE_WITH_READ_USER_SECRET_ID", gitlabTokenSecretId, root)
	if err != nil {
		t.Fatal(err)
	}

	// Print tfvars to output for debug
	printFiles := []string{
		"../../../1-bootstrap/terraform.tfvars",
		"../../../examples/multitenant-applications/4-appfactory/terraform.tfvars",
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

	single_project_root := "../../../examples/standalone_single_project"

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
}

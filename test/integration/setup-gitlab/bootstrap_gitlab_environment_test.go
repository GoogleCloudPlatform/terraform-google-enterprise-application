package bootstrap_gitlab

import (
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/gruntwork-io/terratest/modules/shell"
	gitlab "gitlab.com/gitlab-org/api/client-go"
)

func deleteVM(t *testing.T, instanceName string, instanceZone string, instanceProject string) (string, error) {
	cmd := fmt.Sprintf("compute instances delete %s --zone=%s --project=%s --delete-disks=all --quiet", instanceName, instanceZone, instanceProject)
	args := strings.Fields(cmd)
	gcloudCmd := shell.Command{
		Command: "gcloud",
		Args:    args,
	}
	return shell.RunCommandAndGetStdOutE(t, gcloudCmd)
}

// Will walk directories searching for terraform.tfvars and replace the pattern with the replacement
func replacePatternInTfVars(pattern string, replacement string) error {
	root := "../../../1-bootstrap"
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, fnErr error) error {
		if fnErr != nil {
			return fnErr
		}
		if !d.IsDir() && d.Name() == "terraform.tfvars" {
			return replaceInFile(path, pattern, replacement)
		}
		return nil
	})

	return err
}

func replaceInFile(filePath, oldPattern, newPattern string) error {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return err
	}

	newContent := strings.ReplaceAll(string(content), oldPattern, newPattern)

	err = os.WriteFile(filePath, []byte(newContent), 0644)
	if err != nil {
		return err
	}

	fmt.Printf("Updated file: %s\n", filePath)
	return nil
}

func getTokenFromSecretManager(t *testing.T, secretName string, secretProject string) (string, error) {
	cmd := fmt.Sprintf("secrets versions access latest --project=%s --secret=%s", secretProject, secretName)
	args := strings.Fields(cmd)
	gcloudCmd := shell.Command{
		Command: "gcloud",
		Args:    args,
	}
	return shell.RunCommandAndGetStdOutE(t, gcloudCmd)
}

// connects to a Google Cloud VM instance using SSH and retrieves the logs from the VM's Startup Script service
func readLogsFromVm(t *testing.T, instanceName string, instanceZone string, instanceProject string) (string, error) {
	args := []string{"compute", "ssh", instanceName, fmt.Sprintf("--zone=%s", instanceZone), fmt.Sprintf("--project=%s", instanceProject), "--command=journalctl -u google-startup-scripts.service -n 10"}
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

	// delete VM instance in case the test fails
	defer deleteVM(t, instanceName, instanceZone, gitlabSecretProject)

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

	token, err := getTokenFromSecretManager(t, gitlabPersonalTokenSecretName, gitlabSecretProject)
	if err != nil {
		t.Fatal(err)
	}
	git, err := gitlab.NewClient(token, gitlab.WithBaseURL(url))
	if err != nil {
		t.Fatal(err)
	}
	repos := []string{"eab-multitenant", "eab-fleetscope", "eab-applicationfactory"}
	for _, repo := range repos {
		p := &gitlab.CreateProjectOptions{
			Name:                 gitlab.Ptr(repo),
			Description:          gitlab.Ptr("just testing"),
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

	// Replace gitlab.com/user with custom self hosted URL using the root namespace
	replacement := fmt.Sprintf("%s/root", url)
	err = replacePatternInTfVars("https://gitlab.com/user", replacement)
	if err != nil {
		t.Fatal(err)
	}

	// Replace webhook secret id
	err = replacePatternInTfVars("REPLACE_WITH_WEBHOOK_SECRET_ID", gitlabWebhookSecretId)
	if err != nil {
		t.Fatal(err)
	}

	// Replace gitlab token secret ids
	err = replacePatternInTfVars("REPLACE_WITH_READ_API_SECRET_ID", gitlabTokenSecretId)
	if err != nil {
		t.Fatal(err)
	}

	err = replacePatternInTfVars("REPLACE_WITH_READ_USER_SECRET_ID", gitlabTokenSecretId)
	if err != nil {
		t.Fatal(err)
	}

	// Print tfvars to output for debug
	file, err := os.Open("../../../1-bootstrap/terraform.tfvars")
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		if err = file.Close(); err != nil {
			t.Fatal(err)
		}
	}()

	b, err := io.ReadAll(file)
	t.Log(b)
}

// Copyright 2026 Google LLC
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

package stages

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/gcp"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/steps"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/utils"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/mitchellh/go-testing-interface"
)

const (
	MaxBuildRetries         = 20
	MaxErrorRetries         = 3
	TimeBetweenErrorRetries = 10 * time.Second
)

func getStandalonePaths(EABPath, checkoutPath, exampleName string) (string, string) {
	var relPath string
	if exampleName == "standalone_single_project" || exampleName == "standalone_single_project_confidential_nodes" {
		relPath = filepath.Join("examples", exampleName)
	} else {
		relPath = filepath.Join("examples", exampleName, "standalone-single-project")
	}

	srcPath := filepath.Join(EABPath, relPath)
	destPath := filepath.Join(checkoutPath, relPath)
	return srcPath, destPath
}

func DeployInfraStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, c CommonConf) error {
	srcPath, destPath := getStandalonePaths(c.EABPath, c.CheckoutPath, c.ExampleName)

	// Copy Standalone Code
	err := s.RunStep("gcp-infra.copy-code", func() error {
		err := utils.CopyDirectory(srcPath, destPath)
		if err != nil {
			return err
		}

		// Copy Shared Modules and Policy Library so relative paths (../../../modules/...) resolve perfectly
		err = utils.CopyDirectory(filepath.Join(c.EABPath, "modules"), filepath.Join(c.CheckoutPath, "modules"))
		if err != nil {
			return err
		}

		policySrc := filepath.Join(c.EABPath, "policy-library")
		if _, err := os.Stat(policySrc); err == nil {
			err = utils.CopyDirectory(policySrc, filepath.Join(c.CheckoutPath, "policy-library"))
			if err != nil {
				return err
			}
		}

		// Write HCL terraform.tfvars directly into destPath
		return utils.WriteTfvars(filepath.Join(destPath, "terraform.tfvars"), tfvars)
	})
	if err != nil {
		return err
	}

	// Run Terraform Apply
	err = s.RunStep("gcp-infra.apply", func() error {
		options := &terraform.Options{
			TerraformDir:             destPath,
			Logger:                   c.Logger,
			NoColor:                  true,
			RetryableTerraformErrors: testutils.RetryableTransientErrors,
			MaxRetries:               MaxErrorRetries,
			TimeBetweenRetries:       TimeBetweenErrorRetries,
		}
		_, err = terraform.InitAndApplyE(t, options)
		return err
	})
	return err
}

func getAppSourcePath(c CommonConf, exampleName, serviceName string) string {
	pathsToCheck := []string{
		filepath.Join(c.EABPath, "examples", exampleName, "6-appsource", exampleName, serviceName),
		filepath.Join(c.EABPath, "examples", exampleName, "6-appsource", serviceName),
		filepath.Join(c.EABPath, "examples", exampleName, "6-appsource", exampleName),
		filepath.Join(c.EABPath, "examples", exampleName, "6-appsource"),
	}
	for _, p := range pathsToCheck {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}

func DeployAppSourceStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, c CommonConf) error {
	if tfvars.CloudbuildV2RepositoryConfig == nil {
		return fmt.Errorf("cloudbuildv2_repository_config is required for DeployAppSourceStage")
	}

	_, standaloneDestPath := getStandalonePaths(c.EABPath, c.CheckoutPath, c.ExampleName)
	outputs := GetAppInfraStepOutputs(t, standaloneDestPath)

	var err error
	for serviceName, repository := range tfvars.CloudbuildV2RepositoryConfig.Repositories {
		err = s.RunStep(fmt.Sprintf("gcp-appsource.%s", serviceName), func() error {
			gitPath := filepath.Join(c.CheckoutPath, outputs.ServiceRepositoryName)
			conf := utils.GitClone(t, tfvars.CloudbuildV2RepositoryConfig.RepoType, repository.RepositoryName, repository.RepositoryURL, gitPath, outputs.ServiceRepositoryProjectID, c.Logger)

			err := conf.CheckoutBranch("main")
			if err != nil {
				return err
			}

			// Copy App Source code to target repo
			appSrcDir := getAppSourcePath(c, c.ExampleName, serviceName)
			if appSrcDir == "" {
				return fmt.Errorf("could not find app source path for example %s, service %s", c.ExampleName, serviceName)
			}

			err = utils.CopyDirectory(appSrcDir, gitPath)
			if err != nil {
				return err
			}

			// Commit and push changes to trigger Cloud Build pipeline
			err = conf.CommitFiles(fmt.Sprintf("Initialize %s repo for %s", repository.RepositoryName, serviceName))
			if err != nil {
				return err
			}

			err = conf.PushBranch("main", "origin")
			if err != nil {
				return err
			}

			commitSha, err := conf.GetCommitSha()
			if err != nil {
				return err
			}

			// Monitor build success
			err = gcp.NewGCP().WaitBuildSuccess(t, outputs.ServiceRepositoryProjectID, tfvars.Region, outputs.ServiceRepositoryName, commitSha, fmt.Sprintf("Build for %s failed", serviceName), MaxBuildRetries, MaxErrorRetries, TimeBetweenErrorRetries)
			if err != nil {
				return err
			}

			return nil
		})
		if err != nil {
			return err
		}
	}
	return nil
}

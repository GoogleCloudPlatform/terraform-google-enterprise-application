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
	"strings"
	"sync"
	"time"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/gcp"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/steps"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/utils"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/mitchellh/go-testing-interface"
)

const (
	MaxBuildRetries         = 50
	MaxErrorRetries         = 3
	TimeBetweenErrorRetries = 2 * time.Minute
)

func getStandalonePaths(EABPath, checkoutPath, exampleName string) (string, string, error) {
	normExample := strings.ReplaceAll(exampleName, "_", "-")
	candidates := []string{
		filepath.Join("examples", exampleName, "standalone-single-project"),
		filepath.Join("examples", normExample, "standalone-single-project"),
		filepath.Join("examples", exampleName),
		filepath.Join("examples", normExample),
	}

	for _, relPath := range candidates {
		fullSrc := filepath.Join(EABPath, relPath)
		if fi, err := os.Stat(fullSrc); err == nil && fi.IsDir() {
			return fullSrc, filepath.Join(checkoutPath, relPath), nil
		}
	}

	return "", "", fmt.Errorf("could not find example directory for '%s' in %s", exampleName, EABPath)
}

// DeployInfraStage executes the Terraform provisioning stage for the standalone single project example.
func DeployInfraStage(t testing.TB, s steps.StepManager, tfvars GlobalTFVars, c CommonConf) error {
	srcPath, destPath, err := getStandalonePaths(c.EABPath, c.CheckoutPath, c.ExampleName)
	if err != nil {
		return err
	}

	// Copy Standalone Code
	err = s.RunStep("gcp-infra.copy-code", func() error {
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
	return s.RunStep("gcp-infra.apply", func() error {
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
}

// ServiceDeployer encapsulates the deployment pipeline lifecycle for an individual microservice.
type ServiceDeployer struct {
	StepManager steps.StepManager
	TFVars      GlobalTFVars
	Conf        CommonConf
	Outputs     AppInfraOutputs
	Preparer    AppSourcePreparer
}

func NewServiceDeployer(sm steps.StepManager, tfvars GlobalTFVars, conf CommonConf, outputs AppInfraOutputs, preparer AppSourcePreparer) *ServiceDeployer {
	return &ServiceDeployer{
		StepManager: sm,
		TFVars:      tfvars,
		Conf:        conf,
		Outputs:     outputs,
		Preparer:    preparer,
	}
}

// Deploy prepares the repository, commits files, pushes to remote, and monitors Cloud Build / Cloud Deploy.
func (d *ServiceDeployer) Deploy(t testing.TB, serviceKey string, repo Repository) error {
	stepName := fmt.Sprintf("gcp-appsource.%s", serviceKey)
	return d.StepManager.RunStep(stepName, func() error {
		repoName := repo.RepositoryName
		if repoName == "" {
			if rName, ok := d.Outputs.ServiceRepositoryName[serviceKey]; ok && rName != "" {
				repoName = rName
			} else {
				repoName = serviceKey
			}
		}

		repoProjectID := d.TFVars.ProjectID
		if pID, ok := d.Outputs.ServiceRepositoryProjectID[serviceKey]; ok && pID != "" {
			repoProjectID = pID
		}

		gitPath := filepath.Join(d.Conf.CheckoutPath, repoName)
		conf := utils.GitClone(t, d.TFVars.CloudbuildV2RepositoryConfig.RepoType, repoName, repo.RepositoryURL, gitPath, repoProjectID, d.Conf.Logger)

		if err := conf.CheckoutBranch("main"); err != nil {
			return err
		}

		// Prepare and copy App Source code to target repo using the resolved strategy
		if err := d.Preparer.Prepare(t, d.Conf, d.Outputs.AppSourceRepoURL, d.Outputs.AppVersion, serviceKey, gitPath); err != nil {
			return err
		}

		// Commit and push changes to trigger Cloud Build pipeline
		commitMsg := fmt.Sprintf("Initialize %s repo for %s", repoName, serviceKey)
		if err := conf.CommitFiles(commitMsg); err != nil {
			return err
		}

		if err := conf.PushBranch("main", "origin"); err != nil {
			return err
		}

		commitSha, err := conf.GetCommitSha()
		if err != nil {
			return err
		}

		// Monitor Cloud Build completion
		buildClient := gcp.NewGCP()
		if err := buildClient.WaitBuildSuccess(t, repoProjectID, d.TFVars.Region, repoName, commitSha, fmt.Sprintf("Build for %s failed", serviceKey), MaxBuildRetries, MaxErrorRetries, TimeBetweenErrorRetries); err != nil {
			return err
		}

		// Monitor Cloud Deploy release success if targets are configured
		if targets, ok := d.Outputs.CloudDeployTargetsNames[serviceKey]; ok && len(targets) > 0 {
			shortSha := commitSha
			if len(shortSha) > 7 {
				shortSha = shortSha[:7]
			}
			if err := buildClient.WaitReleaseSuccess(t, repoProjectID, d.TFVars.Region, serviceKey, shortSha, fmt.Sprintf("Cloud Deploy release for %s failed", serviceKey), MaxBuildRetries); err != nil {
				return err
			}
		}

		return nil
	})
}

// DeployAppSourceStage orchestrates the application source preparation and deployment across all microservices in parallel.
func DeployAppSourceStage(t testing.TB, s steps.StepManager, tfvars GlobalTFVars, c CommonConf) error {
	if tfvars.CloudbuildV2RepositoryConfig == nil {
		return fmt.Errorf("cloudbuildv2_repository_config is required for DeployAppSourceStage")
	}

	repos := tfvars.CloudbuildV2RepositoryConfig.Repositories
	if len(repos) == 0 {
		return nil
	}

	_, standaloneDestPath, err := getStandalonePaths(c.EABPath, c.CheckoutPath, c.ExampleName)
	if err != nil {
		return err
	}
	outputs := GetAppInfraStepOutputs(t, standaloneDestPath)
	preparer := GetAppSourcePreparer(c.ExampleName)
	deployer := NewServiceDeployer(s, tfvars, c, outputs, preparer)

	if len(repos) == 1 {
		for serviceKey, repository := range repos {
			return deployer.Deploy(t, serviceKey, repository)
		}
	}

	var wg sync.WaitGroup
	var errMu sync.Mutex
	var errList []error

	for serviceKey, repository := range repos {
		wg.Add(1)
		go func(sKey string, repo Repository) {
			defer wg.Done()
			if err := deployer.Deploy(t, sKey, repo); err != nil {
				errMu.Lock()
				errList = append(errList, fmt.Errorf("service '%s': %w", sKey, err))
				errMu.Unlock()
			}
		}(serviceKey, repository)
	}

	wg.Wait()

	if len(errList) > 0 {
		var errMsgs []string
		for _, e := range errList {
			errMsgs = append(errMsgs, e.Error())
		}
		return fmt.Errorf("failed deploying app source for services:\n%s", strings.Join(errMsgs, "\n"))
	}

	return nil
}

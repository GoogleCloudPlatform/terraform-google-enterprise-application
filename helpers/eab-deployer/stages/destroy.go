// Copyright 2023 Google LLC
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
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/mitchellh/go-testing-interface"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/steps"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/utils"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

func DestroyBootstrapStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, c CommonConf) error {

	if err := forceBackendMigration(t, filepath.Join(c.EABPath, BootstrapStep), c); err != nil {
		return err
	}

	stageConf := StageConf{
		Stage: BootstrapStep,
		Step:  BootstrapStep,
		Repo:  BootstrapRepo,
	}
	return destroyStage(t, stageConf, s, tfvars, c)
}

// forceBackendMigration removes backend.tf file to force migration of the
// terraform state from GCS to the local directory.
// Before changing the backend we ensure it is has been initialized.
func forceBackendMigration(t testing.TB, tfDir string, c CommonConf) error {
	backendF := filepath.Join(tfDir, "backend.tf")

	exist, _ := utils.FileExists(backendF)

	options := &terraform.Options{
		TerraformDir:       tfDir,
		Logger:             c.Logger,
		NoColor:            true,
		MaxRetries:         MaxErrorRetries,
		TimeBetweenRetries: TimeBetweenErrorRetries,
	}
	if exist {
		_, err := terraform.InitE(t, options)
		if err != nil {
			return err
		}
		err = utils.CopyFile(backendF, filepath.Join(tfDir, "backend.tf.backup"))
		if err != nil {
			return err
		}
		err = os.Remove(backendF)
		if err != nil {
			return err
		}

		options.MigrateState = true
		_, err = terraform.InitE(t, options)
		if err != nil {
			return err
		}
	}
	return nil
}

func DestroyMultitenantStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {
	stageConf := StageConf{
		Stage:         tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryName,
		CICDProject:   outputs.ProjectID,
		Step:          MultitenantStep,
		Repo:          tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryName,
		StageSA:       outputs.CBServiceAccountsEmails["multitenant"],
		Envs:          slices.Collect(maps.Keys(tfvars.Envs)),
		GroupingUnits: []string{"envs"},
	}

	return destroyStage(t, stageConf, s, tfvars, c)
}

func DestroyFleetscopeStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {
	stageConf := StageConf{
		Stage:         tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryName,
		CICDProject:   outputs.ProjectID,
		Step:          FleetscopeStep,
		Repo:          tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryName,
		StageSA:       outputs.CBServiceAccountsEmails["fleetscope"],
		Envs:          slices.Collect(maps.Keys(tfvars.Envs)),
		GroupingUnits: []string{"envs"},
	}
	return destroyStage(t, stageConf, s, tfvars, c)
}

func DestroyAppFactoryStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {
	stageConf := StageConf{
		Stage:         tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName,
		StageSA:       outputs.CBServiceAccountsEmails["applicationfactory"],
		CICDProject:   outputs.ProjectID,
		Step:          AppFactoryStep,
		Repo:          tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName,
		Envs:          []string{"shared"},
		GroupingUnits: []string{"envs"},
	}
	return destroyStage(t, stageConf, s, tfvars, c)
}

func DestroyAppInfraStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs AppFactoryOutputs, c CommonConf) error {
	var err error
	for exampleName, services := range tfvars.Applications {
		for serviceName := range services {
			appGroupIndex := fmt.Sprintf("%s.%s", exampleName, serviceName)
			envs := []string{"shared"}
			cbPathEmail := strings.Split(outputs.AppGroup[appGroupIndex].AppCloudbuildWorkspaceCloudbuildSAEmail, "/")
			email := cbPathEmail[len(cbPathEmail)-1]
			stageConf := StageConf{
				Stage:         tfvars.InfraCloudbuildV2RepositoryConfig.Repositories[serviceName].RepositoryName,
				StageSA:       email,
				CICDProject:   outputs.AppGroup[appGroupIndex].AppAdminProjectID,
				Step:          AppInfraStep,
				Repo:          tfvars.InfraCloudbuildV2RepositoryConfig.Repositories[serviceName].RepositoryName,
				Envs:          envs,
				LocalSteps:    envs,
				GroupingUnits: []string{"apps/default-example/hello-world/envs"},
				DefaultRegion: tfvars.TriggerLocation,
			}
			err = destroyStage(t, stageConf, s, tfvars, c)
		}
	}
	return err
}

func destroyStage(t testing.TB, sc StageConf, s steps.Steps, tfvars GlobalTFVars, c CommonConf) error {
	gcpPath := filepath.Join(c.CheckoutPath, sc.Repo)
	stageName := strings.Split(sc.Stage, "-")[1]
	conf := utils.GitRepo{}
	for _, e := range sc.Envs {
		err := s.RunDestroyStep(fmt.Sprintf("%s.%s", sc.Repo, e), func() error {
			for _, g := range sc.GroupingUnits {
				options := &terraform.Options{
					TerraformDir:             filepath.Join(gcpPath, g, e),
					Logger:                   c.Logger,
					NoColor:                  true,
					RetryableTerraformErrors: testutils.RetryableTransientErrors,
					MaxRetries:               MaxErrorRetries,
					TimeBetweenRetries:       TimeBetweenErrorRetries,
				}

				gitPath := filepath.Join(c.CheckoutPath, tfvars.InfraCloudbuildV2RepositoryConfig.Repositories[stageName].RepositoryName)
				conf = utils.GitClone(t, tfvars.InfraCloudbuildV2RepositoryConfig.RepoType, tfvars.InfraCloudbuildV2RepositoryConfig.Repositories[stageName].RepositoryName, tfvars.InfraCloudbuildV2RepositoryConfig.Repositories[stageName].RepositoryURL, gitPath, sc.CICDProject, c.Logger)

				branch := e
				if branch == "shared" {
					branch = "production"
				}
				err := conf.CheckoutBranch(branch)
				if err != nil {
					return err
				}
				err = destroyEnv(t, options, sc.StageSA)
				if err != nil {
					return err
				}
			}
			return nil
		})
		if err != nil {
			return err
		}
	}
	groupingUnits := []string{}
	if sc.HasLocalStep {
		groupingUnits = sc.GroupingUnits
	}
	for _, g := range groupingUnits {
		err := s.RunDestroyStep(fmt.Sprintf("%s.%s.apply-shared", sc.Repo, g), func() error {
			options := &terraform.Options{
				TerraformDir:             filepath.Join(gcpPath, g, "shared"),
				Logger:                   c.Logger,
				NoColor:                  true,
				RetryableTerraformErrors: testutils.RetryableTransientErrors,
				MaxRetries:               MaxErrorRetries,
				TimeBetweenRetries:       TimeBetweenErrorRetries,
			}
			t.Log("Clonning repo")

			gitPath := filepath.Join(c.CheckoutPath, tfvars.InfraCloudbuildV2RepositoryConfig.Repositories[stageName].RepositoryName)
			conf := utils.GitClone(t, tfvars.InfraCloudbuildV2RepositoryConfig.RepoType, tfvars.InfraCloudbuildV2RepositoryConfig.Repositories[stageName].RepositoryName, tfvars.InfraCloudbuildV2RepositoryConfig.Repositories[stageName].RepositoryURL, gitPath, sc.CICDProject, c.Logger)

			err := conf.CheckoutBranch("production")
			if err != nil {
				return err
			}
			return destroyEnv(t, options, sc.StageSA)
		})
		if err != nil {
			return err
		}
	}

	if len(groupingUnits) == 0 && len(sc.Envs) == 0 {
		err := s.RunDestroyStep(fmt.Sprintf("%s", sc.Repo), func() error {
			options := &terraform.Options{
				TerraformDir:             filepath.Join(c.EABPath, sc.Stage),
				Logger:                   c.Logger,
				NoColor:                  true,
				RetryableTerraformErrors: testutils.RetryableTransientErrors,
				MaxRetries:               MaxErrorRetries,
				TimeBetweenRetries:       TimeBetweenErrorRetries,
			}
			err := destroyEnv(t, options, sc.StageSA)
			if err != nil {
				return err
			}

			return nil
		})
		if err != nil {
			return err
		}
	}

	fmt.Println("end of", sc.Step, "destroy")
	return nil
}

func destroyEnv(t testing.TB, options *terraform.Options, serviceAccount string) error {
	var err error

	if serviceAccount != "" {
		t.Log(fmt.Sprintf("Setting GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=%s", serviceAccount))
		err = os.Setenv("GOOGLE_IMPERSONATE_SERVICE_ACCOUNT", serviceAccount)
		if err != nil {
			return err
		}
	}

	_, err = terraform.InitE(t, options)
	if err != nil {
		return err
	}
	_, err = terraform.DestroyE(t, options)
	if err != nil {
		return err
	}

	if serviceAccount != "" {
		err = os.Unsetenv("GOOGLE_IMPERSONATE_SERVICE_ACCOUNT")
		if err != nil {
			return err
		}
	}
	return nil
}

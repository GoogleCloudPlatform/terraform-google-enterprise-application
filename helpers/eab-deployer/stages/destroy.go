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
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/mitchellh/go-testing-interface"

	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/steps"
	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/utils"
	"github.com/terraform-google-modules/terraform-example-foundation/test/integration/testutils"
)

const (
	MaxBuildRetries = 60
)

func DestroyBootstrapStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, c CommonConf) error {

	if err := forceBackendMigration(t, BootstrapRepo, "envs", "shared", c); err != nil {
		return err
	}

	stageConf := StageConf{
		Stage:         BootstrapStep,
		Step:          BootstrapStep,
		Repo:          BootstrapRepo,
		GroupingUnits: []string{"envs"},
		Envs:          []string{"shared"},
	}
	return destroyStage(t, stageConf, s, tfvars, c)
}

// forceBackendMigration removes backend.tf file to force migration of the
// terraform state from GCS to the local directory.
// Before changing the backend we ensure it is has been initialized.
func forceBackendMigration(t testing.TB, repo, groupUnit, env string, c CommonConf) error {
	tfDir := filepath.Join(c.CheckoutPath, repo, groupUnit, env)
	backendF := filepath.Join(tfDir, "backend.tf")

	exist, err := utils.FileExists(backendF)
	if err != nil {
		return err
	}
	if exist {
		options := &terraform.Options{
			TerraformDir: tfDir,
			Logger:       c.Logger,
			NoColor:      true,
		}
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
		Stage:       tfvars.CloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryName,
		CICDProject: outputs.ProjectID,
		Step:        MultitenantStep,
		Repo:        tfvars.CloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryURL,
		StageSA:     outputs.CBServiceAccountsEmails["multitenant"],
		Envs:        slices.Collect(maps.Keys(tfvars.Envs)),
	}

	return destroyStage(t, stageConf, s, tfvars, c)
}

func DestroyFleetscopeStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {
	stageConf := StageConf{
		Stage:       tfvars.CloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryName,
		CICDProject: outputs.ProjectID,
		Step:        FleetscopeStep,
		Repo:        tfvars.CloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryURL,
		StageSA:     outputs.CBServiceAccountsEmails["fleetscope"],
		Envs:        slices.Collect(maps.Keys(tfvars.Envs)),
	}
	return destroyStage(t, stageConf, s, tfvars, c)
}

func DestroyAppFactoryStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {
	stageConf := StageConf{
		Stage:         tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName,
		StageSA:       outputs.CBServiceAccountsEmails["appfactory"],
		CICDProject:   outputs.ProjectID,
		Step:          AppFactoryStep,
		Repo:          tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryURL,
		HasLocalStep:  true,
		LocalSteps:    []string{"shared"},
		GroupingUnits: []string{"envs"},
	}
	return destroyStage(t, stageConf, s, tfvars, c)
}

func DestroyAppInfraStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs AppFactoryOutputs, c CommonConf) error {
	stageConf := StageConf{
		Stage:         tfvars.CloudbuildV2RepositoryConfig.Repositories["hello-world"].RepositoryName,
		StageSA:       outputs.AppGroup["default-example"].AppCloudbuildWorkspaceCloudbuildSAEmail,
		CICDProject:   outputs.AppGroup["default-example"].AppAdminProjectID,
		Step:          AppInfraStep,
		Repo:          tfvars.CloudbuildV2RepositoryConfig.Repositories["hello-world"].RepositoryURL,
		HasLocalStep:  false,
		GroupingUnits: []string{"apps"},
		Envs:          []string{"default-example"},
	}
	return destroyStage(t, stageConf, s, tfvars, c)
}

func destroyStage(t testing.TB, sc StageConf, s steps.Steps, tfvars GlobalTFVars, c CommonConf) error {
	gcpPath := filepath.Join(c.CheckoutPath, sc.Repo)
	for _, e := range sc.Envs {
		err := s.RunDestroyStep(fmt.Sprintf("%s.%s", sc.Repo, e), func() error {
			for _, g := range sc.GroupingUnits {
				options := &terraform.Options{
					TerraformDir:             filepath.Join(gcpPath, g, e),
					Logger:                   c.Logger,
					NoColor:                  true,
					RetryableTerraformErrors: testutils.RetryableTransientErrors,
					MaxRetries:               2,
					TimeBetweenRetries:       2 * time.Minute,
				}
				conf := utils.CloneCSR(t, sc.Repo, gcpPath, sc.CICDProject, c.Logger)
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
				MaxRetries:               2,
				TimeBetweenRetries:       2 * time.Minute,
			}
			conf := utils.CloneCSR(t, tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryURL, gcpPath, sc.CICDProject, c.Logger)
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

	fmt.Println("end of", sc.Step, "destroy")
	return nil
}

func destroyEnv(t testing.TB, options *terraform.Options, serviceAccount string) error {
	var err error

	if serviceAccount != "" {
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

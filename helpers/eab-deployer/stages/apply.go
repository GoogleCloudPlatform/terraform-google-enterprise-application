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
	"os"
	"path/filepath"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/mitchellh/go-testing-interface"

	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/gcp"
	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/msg"
	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/steps"
	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/utils"
)

func DeployBootstrapStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, c CommonConf) error {
	bootstrapTfvars := BootstrapTfvars{
		ProjectID:                    tfvars.ProjectID,
		BucketPrefix:                 tfvars.BucketPrefix,
		BucketForceDestroy:           tfvars.BucketForceDestroy,
		Location:                     tfvars.Location,
		TriggerLocation:              tfvars.TriggerLocation,
		TFApplyBranches:              tfvars.TFApplyBranches,
		Envs:                         tfvars.Envs,
		CommonFolderID:               tfvars.CommonFolderID,
		CloudbuildV2RepositoryConfig: tfvars.CloudbuildV2RepositoryConfig,
		WorkerPoolID:                 tfvars.WorkerPoolID,
		AccessLevelName:              tfvars.AccessLevelName,
		ServicePerimeterName:         tfvars.ServicePerimeterName,
		ServicePerimeterMode:         tfvars.ServicePerimeterMode,
		LoggingBucket:                tfvars.LoggingBucket,
		BucketKMSKey:                 tfvars.BucketKMSKey,
		AttestationKMSProject:        tfvars.AttestationKMSProject,
		OrgID:                        tfvars.OrgID,
	}

	err := utils.WriteTfvars(filepath.Join(c.EABPath, BootstrapStep, "terraform.tfvars"), bootstrapTfvars)
	if err != nil {
		return err
	}

	// delete README-Jenkins.md due to private key checker false positive
	jenkinsReadme := filepath.Join(c.EABPath, BootstrapStep, "README-Jenkins.md")
	exist, err := utils.FileExists(jenkinsReadme)
	if err != nil {
		return err
	}
	if exist {
		err = os.Remove(jenkinsReadme)
		if err != nil {
			return err
		}
	}

	terraformDir := filepath.Join(c.EABPath, BootstrapStep)
	options := &terraform.Options{
		TerraformDir: terraformDir,
		Logger:       c.Logger,
		NoColor:      true,
	}
	// terraform deploy
	err = applyLocal(t, options, "", c.PolicyPath, c.ValidatorProject)
	if err != nil {
		return err
	}

	// read bootstrap outputs
	defaultRegion := terraform.OutputMap(t, options, "common_config")["default_region"]
	cbProjectID := terraform.Output(t, options, "cloudbuild_project_id")
	backendBucket := terraform.Output(t, options, "gcs_bucket_tfstate")
	backendBucketProjects := terraform.Output(t, options, "projects_gcs_bucket_tfstate")

	// replace backend and terraform init migrate
	err = s.RunStep("gcp-bootstrap.migrate-state", func() error {
		options.MigrateState = true
		err = utils.CopyFile(filepath.Join(options.TerraformDir, "backend.tf.example"), filepath.Join(options.TerraformDir, "backend.tf"))
		if err != nil {
			return err
		}
		err = utils.ReplaceStringInFile(filepath.Join(options.TerraformDir, "backend.tf"), "UPDATE_ME", backendBucket)
		if err != nil {
			return err
		}
		_, err := terraform.InitE(t, options)
		return err
	})
	if err != nil {
		return err
	}

	// replace all backend files
	err = s.RunStep("gcp-bootstrap.replace-backend-files", func() error {
		files, err := utils.FindFiles(c.EABPath, "backend.tf")
		if err != nil {
			return err
		}
		for _, file := range files {
			err = utils.ReplaceStringInFile(file, "UPDATE_ME", backendBucket)
			if err != nil {
				return err
			}
			err = utils.ReplaceStringInFile(file, "UPDATE_PROJECTS_BACKEND", backendBucketProjects)
			if err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return err
	}

	msg.PrintBuildMsg(cbProjectID, defaultRegion, c.DisablePrompt)

	// Check if image build was successful.
	err = gcp.NewGCP().WaitBuildSuccess(t, cbProjectID, defaultRegion, "tf-cloudbuilder", "", "Terraform Image builder Build Failed for tf-cloudbuilder repository.", MaxBuildRetries)
	if err != nil {
		return err
	}

	//prepare policies repo
	gcpPoliciesPath := filepath.Join(c.CheckoutPath, PoliciesRepo)
	policiesConf := utils.CloneCSR(t, PoliciesRepo, gcpPoliciesPath, cbProjectID, c.Logger)
	policiesBranch := "main"

	err = s.RunStep("gcp-bootstrap.gcp-policies", func() error {
		return preparePoliciesRepo(policiesConf, policiesBranch, c.EABPath, gcpPoliciesPath)
	})
	if err != nil {
		return err
	}

	//prepare bootstrap repo
	gcpBootstrapPath := filepath.Join(c.CheckoutPath, BootstrapRepo)
	bootstrapConf := utils.CloneCSR(t, BootstrapRepo, gcpBootstrapPath, cbProjectID, c.Logger)
	stageConf := StageConf{
		Stage:               BootstrapRepo,
		CICDProject:         cbProjectID,
		DefaultRegion:       defaultRegion,
		Step:                BootstrapStep,
		Repo:                BootstrapRepo,
		CustomTargetDirPath: "envs/shared",
		GitConf:             bootstrapConf,
		Envs:                []string{"shared"},
	}

	err = deployStage(t, stageConf, s, c)

	if err != nil {
		return err
	}
	// Init gcp-bootstrap terraform
	err = s.RunStep("gcp-bootstrap.init-tf", func() error {
		options := &terraform.Options{
			TerraformDir: filepath.Join(gcpBootstrapPath, "envs", "shared"),
			Logger:       c.Logger,
			NoColor:      true,
		}
		_, err := terraform.InitE(t, options)
		return err
	})
	if err != nil {
		return err
	}
	fmt.Println("end of bootstrap deploy")

	return nil
}

func DeployMultitenantStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {

	multitenantTfvars := MultiTenantTfvars{
		Envs:                         tfvars.Envs,
		Apps:                         tfvars.Apps,
		ServicePerimeterName:         tfvars.ServicePerimeterName,
		ServicePerimeterMode:         tfvars.ServicePerimeterMode,
		CBPrivateWorkerpoolProjectID: tfvars.CBPrivateWorkerpoolProjectID,
		AccessLevelName:              tfvars.AccessLevelName,
		DeletionProtection:           tfvars.DeletionProtection,
	}
	err := utils.WriteTfvars(filepath.Join(c.EABPath, "terraform.tfvars"), multitenantTfvars)
	if err != nil {
		return err
	}

	conf := utils.CloneCSR(t, MultitenantRepo, filepath.Join(c.CheckoutPath, MultitenantRepo), outputs.ProjectID, c.Logger)
	stageConf := StageConf{
		Stage:       MultitenantRepo,
		CICDProject: outputs.ProjectID,
		Step:        MultitenantStep,
		Repo:        MultitenantRepo,
		StageSA:     outputs.CBServiceAccountsEmails["multitenant"],
		GitConf:     conf,
		Envs:        []string{"production", "nonproduction", "development"},
	}

	return deployStage(t, stageConf, s, c)
}

func DeployFleetscopeStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {

	fleetscopeTfvars := FleetscopeTfvars{
		RemoteStateBucket:         outputs.StateBucket,
		NamespaceIDs:              tfvars.NamespaceIDs,
		ConfigSyncSecretType:      tfvars.ConfigSyncSecretType,
		ConfigSyncRepositoryURL:   tfvars.ConfigSyncRepositoryURL,
		DisableIstioOnNamespaces:  tfvars.DisableIstioOnNamespaces,
		ConfigSyncPolicyDir:       tfvars.ConfigSyncPolicyDir,
		ConfigSyncBranch:          tfvars.ConfigSyncBranch,
		AttestationKMSKey:         tfvars.AttestationKMSKey,
		AttestationEvaluationMode: tfvars.AttestationEvaluationMode,
		EnableKueue:               tfvars.EnableKueue,
	}
	err := utils.WriteTfvars(filepath.Join(c.EABPath, FleetscopeStep, "terraform.tfvars"), fleetscopeTfvars)
	if err != nil {
		return err
	}

	conf := utils.CloneCSR(t, FleetscopeRepo, filepath.Join(c.CheckoutPath, FleetscopeRepo), outputs.ProjectID, c.Logger)
	stageConf := StageConf{
		Stage:       FleetscopeRepo,
		CICDProject: outputs.ProjectID,
		Step:        FleetscopeStep,
		Repo:        FleetscopeRepo,
		StageSA:     outputs.CBServiceAccountsEmails["fleetscope"],
		GitConf:     conf,
		Envs:        []string{"production", "nonproduction", "development"},
	}

	return deployStage(t, stageConf, s, c)
}

func DeployAppFactoryStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {

	conf := utils.CloneCSR(t, AppFactoryRepo, filepath.Join(c.CheckoutPath, AppFactoryRepo), outputs.ProjectID, c.Logger)
	stageConf := StageConf{
		Stage:         AppFactoryRepo,
		StageSA:       outputs.CBServiceAccountsEmails["appfactory"],
		CICDProject:   outputs.ProjectID,
		Step:          AppFactoryStep,
		Repo:          AppFactoryRepo,
		GitConf:       conf,
		HasLocalStep:  true,
		LocalSteps:    []string{"shared"},
		GroupingUnits: []string{"envs"},
	}
	return deployStage(t, stageConf, s, c)
}

func DeployAppInfraStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs AppFactoryOutputs, c CommonConf) error {
	//for each environment
	appInfraTfvars := AppInfraTfvars{
		Region:                       tfvars.Region,
		BucketsForceDestroy:          tfvars.BucketsForceDestroy,
		RemoteStateBucket:            tfvars.RemoteStateBucket,
		EnvironmentNames:             tfvars.EnvironmentNames,
		CloudbuildV2RepositoryConfig: tfvars.CloudbuildV2RepositoryConfig,
		AccessLevelName:              tfvars.AccessLevelName,
		LoggingBucket:                tfvars.LoggingBucket,
		BucketKMSKey:                 tfvars.BucketKMSKey,
		AttestationKMSKey:            tfvars.AttestationKMSKey,
	}

	err := utils.WriteTfvars(filepath.Join(c.EABPath, AppInfraRepo, "terraform.tfvars"), appInfraTfvars)
	if err != nil {
		return err
	}

	conf := utils.CloneCSR(t, AppInfraRepo, filepath.Join(c.CheckoutPath, AppInfraRepo), outputs.AppGroup["default-example"].AppAdminProjectID, c.Logger)
	stageConf := StageConf{
		Stage:         AppInfraRepo,
		StageSA:       outputs.AppGroup["default-example"].AppCloudbuildWorkspaceCloudbuildSAEmail,
		CICDProject:   outputs.AppGroup["default-example"].AppAdminProjectID,
		Step:          AppInfraStep,
		Repo:          AppInfraRepo,
		GitConf:       conf,
		HasLocalStep:  false,
		GroupingUnits: []string{"apps"},
		Envs:          []string{"default-example"},
	}

	return deployStage(t, stageConf, s, c)

}

func DeployAppSourceStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs AppInfraOutputs, c CommonConf) error {

	conf := utils.CloneCSR(t, AppInfraRepo, filepath.Join(c.CheckoutPath, AppInfraRepo), outputs.ServiceRepositoryProjectID, c.Logger)
	stageConf := StageConf{
		Stage:       AppInfraRepo,
		CICDProject: outputs.ServiceRepositoryProjectID,
		Step:        AppInfraStep,
		Repo:        AppInfraRepo,
		GitConf:     conf,
		Envs:        []string{"hello-world"},
	}

	return deployStage(t, stageConf, s, c)
}

func deployStage(t testing.TB, sc StageConf, s steps.Steps, c CommonConf) error {

	err := sc.GitConf.CheckoutBranch("plan")
	if err != nil {
		return err
	}

	err = s.RunStep(fmt.Sprintf("%s.copy-code", sc.Stage), func() error {
		return copyStepCode(t, sc.GitConf, c.EABPath, c.CheckoutPath, sc.Repo, sc.Step, sc.CustomTargetDirPath)
	})
	if err != nil {
		return err
	}

	groupunit := []string{}
	if sc.HasLocalStep {
		groupunit = sc.GroupingUnits
	}

	for _, bu := range groupunit {
		for _, localStep := range sc.LocalSteps {
			buOptions := &terraform.Options{
				TerraformDir: filepath.Join(filepath.Join(c.CheckoutPath, sc.Repo), bu, localStep),
				Logger:       c.Logger,
				NoColor:      true,
			}

			err := s.RunStep(fmt.Sprintf("%s.%s.apply-%s", sc.Stage, bu, localStep), func() error {
				return applyLocal(t, buOptions, sc.StageSA, c.PolicyPath, c.ValidatorProject)
			})
			if err != nil {
				return err
			}
		}
	}

	err = s.RunStep(fmt.Sprintf("%s.plan", sc.Stage), func() error {
		return planStage(t, sc.GitConf, sc.CICDProject, sc.DefaultRegion, sc.Repo)
	})
	if err != nil {
		return err
	}

	for _, env := range sc.Envs {
		err = s.RunStep(fmt.Sprintf("%s.%s", sc.Stage, env), func() error {
			aEnv := env
			if env == "shared" {
				aEnv = "production"
			}
			return applyEnv(t, sc.GitConf, sc.CICDProject, sc.DefaultRegion, sc.Repo, aEnv)
		})
		if err != nil {
			return err
		}
	}

	fmt.Println("end of", sc.Step, "deploy")
	return nil
}

func preparePoliciesRepo(policiesConf utils.GitRepo, policiesBranch, EABPath, gcpPoliciesPath string) error {
	err := policiesConf.CheckoutBranch(policiesBranch)
	if err != nil {
		return err
	}
	err = utils.CopyDirectory(filepath.Join(EABPath, "policy-library"), gcpPoliciesPath)
	if err != nil {
		return err
	}
	err = policiesConf.CommitFiles("Initialize policy library repo")
	if err != nil {
		return err
	}
	return policiesConf.PushBranch(policiesBranch, "origin")
}

func copyStepCode(t testing.TB, conf utils.GitRepo, EABPath, checkoutPath, repo, step, customPath string) error {
	gcpPath := filepath.Join(checkoutPath, repo)
	targetDir := gcpPath
	if customPath != "" {
		targetDir = filepath.Join(gcpPath, customPath)
	}
	err := utils.CopyDirectory(filepath.Join(EABPath, step), targetDir)
	if err != nil {
		return err
	}
	err = utils.CopyFile(filepath.Join(EABPath, "build/cloudbuild-tf-apply.yaml"), filepath.Join(gcpPath, "cloudbuild-tf-apply.yaml"))
	if err != nil {
		return err
	}
	err = utils.CopyFile(filepath.Join(EABPath, "build/cloudbuild-tf-plan.yaml"), filepath.Join(gcpPath, "cloudbuild-tf-plan.yaml"))
	if err != nil {
		return err
	}
	return utils.CopyFile(filepath.Join(EABPath, "build/tf-wrapper.sh"), filepath.Join(gcpPath, "tf-wrapper.sh"))
}

func planStage(t testing.TB, conf utils.GitRepo, project, region, repo string) error {

	err := conf.CommitFiles(fmt.Sprintf("Initialize %s repo", repo))
	if err != nil {
		return err
	}
	err = conf.PushBranch("plan", "origin")
	if err != nil {
		return err
	}

	commitSha, err := conf.GetCommitSha()
	if err != nil {
		return err
	}

	return gcp.NewGCP().WaitBuildSuccess(t, project, region, repo, commitSha, fmt.Sprintf("Terraform %s plan build Failed.", repo), MaxBuildRetries)
}

func saveBootstrapCodeOnly(t testing.TB, sc StageConf, s steps.Steps, c CommonConf) error {

	err := sc.GitConf.CheckoutBranch("plan")
	if err != nil {
		return err
	}

	err = s.RunStep(fmt.Sprintf("%s.copy-code", sc.Stage), func() error {
		return copyStepCode(t, sc.GitConf, c.EABPath, c.CheckoutPath, sc.Repo, sc.Step, sc.CustomTargetDirPath)
	})
	if err != nil {
		return err
	}

	err = s.RunStep(fmt.Sprintf("%s.plan", sc.Stage), func() error {
		err := sc.GitConf.CommitFiles(fmt.Sprintf("Initialize %s repo", sc.Repo))
		if err != nil {
			return err
		}
		return sc.GitConf.PushBranch("plan", "origin")
	})

	if err != nil {
		return err
	}

	for _, env := range sc.Envs {
		err = s.RunStep(fmt.Sprintf("%s.%s", sc.Stage, env), func() error {
			aEnv := env
			if env == "shared" {
				aEnv = "production"
			}
			err := sc.GitConf.CheckoutBranch(aEnv)
			if err != nil {
				return err
			}
			return sc.GitConf.PushBranch(aEnv, "origin")
		})
		if err != nil {
			return err
		}
	}

	fmt.Println("end of", sc.Step, "deploy")
	return nil
}

func applyEnv(t testing.TB, conf utils.GitRepo, project, region, repo, environment string) error {
	err := conf.CheckoutBranch(environment)
	if err != nil {
		return err
	}
	err = conf.PushBranch(environment, "origin")
	if err != nil {
		return err
	}
	commitSha, err := conf.GetCommitSha()
	if err != nil {
		return err
	}

	return gcp.NewGCP().WaitBuildSuccess(t, project, region, repo, commitSha, fmt.Sprintf("Terraform %s apply %s build Failed.", repo, environment), MaxBuildRetries)
}

func applyLocal(t testing.TB, options *terraform.Options, serviceAccount, policyPath, validatorProjectId string) error {
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
	_, err = terraform.PlanE(t, options)
	if err != nil {
		return err
	}

	// Runs gcloud terraform vet
	if validatorProjectId != "" {
		err = TerraformVet(t, options.TerraformDir, policyPath, validatorProjectId)
		if err != nil {
			return err
		}
	}

	_, err = terraform.ApplyE(t, options)
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

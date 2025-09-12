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

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/mitchellh/go-testing-interface"

	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/gcp"
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
		TFApplyBranches:              slices.Collect(maps.Keys(tfvars.Envs)),
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

	backendBucket := terraform.Output(t, options, "state_bucket")

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
			// err = utils.ReplaceStringInFile(file, "UPDATE_PROJECTS_BACKEND", backendBucketProjects)
			// if err != nil {
			// 	return err
			// }
		}
		return nil
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
	err := utils.WriteTfvars(filepath.Join(c.EABPath, MultitenantStep, "terraform.tfvars"), multitenantTfvars)
	if err != nil {
		return err
	}

	conf := utils.GitRepo{}
	if tfvars.CloudbuildV2RepositoryConfig.RepoType != "CSR" {
		conf = utils.CloneGit(t, tfvars.CloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryURL, filepath.Join(c.CheckoutPath, tfvars.CloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryName), c.Logger)
	} else {
		conf = utils.CloneCSR(t, tfvars.CloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryURL, filepath.Join(c.CheckoutPath, tfvars.CloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryName), outputs.ProjectID, c.Logger)
	}
	stageConf := StageConf{
		Stage:         tfvars.CloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryName,
		CICDProject:   outputs.ProjectID,
		Step:          MultitenantStep,
		Repo:          tfvars.CloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryName,
		StageSA:       outputs.CBServiceAccountsEmails["multitenant"],
		GitConf:       conf,
		Envs:          slices.Collect(maps.Keys(tfvars.Envs)),
		DefaultRegion: tfvars.TriggerLocation,
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

	conf := utils.GitRepo{}
	if tfvars.CloudbuildV2RepositoryConfig.RepoType != "CSR" {
		conf = utils.CloneGit(t, tfvars.CloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryURL, filepath.Join(c.CheckoutPath, tfvars.CloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryName), c.Logger)
	} else {
		conf = utils.CloneCSR(t, tfvars.CloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryURL, filepath.Join(c.CheckoutPath, tfvars.CloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryName), outputs.ProjectID, c.Logger)
	}

	stageConf := StageConf{
		Stage:         tfvars.CloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryName,
		CICDProject:   outputs.ProjectID,
		Step:          FleetscopeStep,
		Repo:          tfvars.CloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryName,
		StageSA:       outputs.CBServiceAccountsEmails["fleetscope"],
		GitConf:       conf,
		Envs:          slices.Collect(maps.Keys(tfvars.Envs)),
		DefaultRegion: tfvars.TriggerLocation,
	}

	return deployStage(t, stageConf, s, c)
}

func DeployAppFactoryStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {

	appFactory := AppFactoryTfvars{
		RemoteStateBucket:            outputs.StateBucket,
		CommonFolderID:               tfvars.CommonFolderID,
		OrgID:                        tfvars.OrgID,
		BillingAccount:               tfvars.BillingAccount,
		Envs:                         tfvars.Envs,
		BucketPrefix:                 tfvars.BucketPrefix,
		BucketForceDestroy:           tfvars.BucketForceDestroy,
		Location:                     tfvars.Location,
		TriggerLocation:              tfvars.TriggerLocation,
		TFApplyBranches:              slices.Collect(maps.Keys(tfvars.Envs)),
		Applications:                 tfvars.Applications,
		CloudbuildV2RepositoryConfig: tfvars.CloudbuildV2RepositoryConfig,
		KMSProjectID:                 tfvars.KMSProjectID,
		ServicePerimeterName:         tfvars.ServicePerimeterName,
		ServicePerimeterMode:         *tfvars.ServicePerimeterMode,
		InfraProjectAPIs:             tfvars.InfraProjectAPIs,
	}
	err := utils.WriteTfvars(filepath.Join(c.EABPath, AppFactoryStep, "terraform.tfvars"), appFactory)
	if err != nil {
		return err
	}

	conf := utils.GitRepo{}
	if tfvars.CloudbuildV2RepositoryConfig.RepoType != "CSR" {
		conf = utils.CloneGit(t, tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryURL, filepath.Join(c.CheckoutPath, tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName), c.Logger)
	} else {
		conf = utils.CloneCSR(t, tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryURL, filepath.Join(c.CheckoutPath, tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName), outputs.ProjectID, c.Logger)
	}

	stageConf := StageConf{
		Stage:         tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName,
		StageSA:       outputs.CBServiceAccountsEmails["applicationfactory"],
		CICDProject:   outputs.ProjectID,
		Step:          AppFactoryStep,
		Repo:          tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName,
		GitConf:       conf,
		HasLocalStep:  true,
		LocalSteps:    []string{"shared"},
		GroupingUnits: []string{"envs"},
		DefaultRegion: tfvars.TriggerLocation,
	}
	return deployStage(t, stageConf, s, c)
}

func DeployAppInfraStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs AppFactoryOutputs, c CommonConf) error {
	//for each environment
	appInfraTfvars := AppInfraTfvars{
		Region:                       tfvars.Region,
		BucketsForceDestroy:          tfvars.BucketsForceDestroy,
		RemoteStateBucket:            tfvars.RemoteStateBucket,
		EnvironmentNames:             slices.Collect(maps.Keys(tfvars.Envs)),
		CloudbuildV2RepositoryConfig: tfvars.CloudbuildV2RepositoryConfig,
		AccessLevelName:              tfvars.AccessLevelName,
		LoggingBucket:                tfvars.LoggingBucket,
		BucketKMSKey:                 tfvars.BucketKMSKey,
		AttestationKMSKey:            tfvars.AttestationKMSKey,
	}

	err := utils.WriteTfvars(filepath.Join(c.EABPath, tfvars.CloudbuildV2RepositoryConfig.Repositories["appinfra"].RepositoryURL, "terraform.tfvars"), appInfraTfvars)
	if err != nil {
		return err
	}

	conf := utils.GitRepo{}
	if tfvars.CloudbuildV2RepositoryConfig.RepoType != "CSR" {
		conf = utils.CloneGit(t, tfvars.CloudbuildV2RepositoryConfig.Repositories["hello-world"].RepositoryURL, filepath.Join(c.CheckoutPath, tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName), c.Logger)
	} else {
		conf = utils.CloneCSR(t, tfvars.CloudbuildV2RepositoryConfig.Repositories["hello-world"].RepositoryURL, filepath.Join(c.CheckoutPath, tfvars.CloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName), outputs.AppGroup["default-example"].AppAdminProjectID, c.Logger)
	}
	stageConf := StageConf{
		Stage:         tfvars.CloudbuildV2RepositoryConfig.Repositories["hello-world"].RepositoryName,
		StageSA:       outputs.AppGroup["default-example"].AppCloudbuildWorkspaceCloudbuildSAEmail,
		CICDProject:   outputs.AppGroup["default-example"].AppAdminProjectID,
		Step:          AppInfraStep,
		Repo:          tfvars.CloudbuildV2RepositoryConfig.Repositories["hello-world"].RepositoryName,
		GitConf:       conf,
		HasLocalStep:  false,
		GroupingUnits: []string{"apps"},
		Envs:          []string{"default-example"},
		DefaultRegion: tfvars.TriggerLocation,
	}

	return deployStage(t, stageConf, s, c)

}

func DeployAppSourceStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs AppInfraOutputs, c CommonConf) error {

	conf := utils.GitRepo{}
	if tfvars.CloudbuildV2RepositoryConfig.RepoType != "CSR" {
		conf = utils.CloneGit(t, outputs.ServiceRepositoryName, filepath.Join(c.CheckoutPath, outputs.ServiceRepositoryName), c.Logger)
	} else {
		conf = utils.CloneCSR(t, outputs.ServiceRepositoryName, filepath.Join(c.CheckoutPath, outputs.ServiceRepositoryName), outputs.ServiceRepositoryProjectID, c.Logger)
	}
	stageConf := StageConf{
		Stage:         outputs.ServiceRepositoryName,
		CICDProject:   outputs.ServiceRepositoryProjectID,
		Step:          AppInfraStep,
		Repo:          outputs.ServiceRepositoryName,
		GitConf:       conf,
		Envs:          []string{"hello-world"},
		DefaultRegion: tfvars.TriggerLocation,
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
	fmt.Println(targetDir)
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
		t.Logf("Setting GOOGLE_IMPERSONATE_SERVICE_ACCOUNT as %s", serviceAccount)
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

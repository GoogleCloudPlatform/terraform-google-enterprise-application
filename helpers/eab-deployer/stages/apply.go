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

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/gcp"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/steps"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/utils"
)

func DeployBootstrapStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, c CommonConf) error {
	var kmsProject *string
	if tfvars.AttestationKMSKey != nil {
		kmsInfo, err := extractInfoWithRegex(*tfvars.AttestationKMSKey, `projects/(?P<project>[^/]+)/locations/(?P<location>[^/]+)/keyRings/(?P<keyRing>[^/]+)/cryptoKeys/(?P<cryptoKey>[^/]+)`)
		if err != nil {
			fmt.Printf("# error extracting info for attestation KMS key. %v \n", err)
			return err
		}

		if len(kmsInfo) > 0 {
			auxProject := kmsInfo["project"]
			kmsProject = &auxProject
		}
	}
	bootstrapTfvars := BootstrapTfvars{
		ProjectID:                    tfvars.ProjectID,
		BucketPrefix:                 tfvars.BucketPrefix,
		BucketForceDestroy:           tfvars.BucketForceDestroy,
		Location:                     tfvars.Location,
		TriggerLocation:              tfvars.TriggerLocation,
		TFApplyBranches:              slices.Collect(maps.Keys(tfvars.Envs)),
		Envs:                         tfvars.Envs,
		CommonFolderID:               tfvars.CommonFolderID,
		CloudbuildV2RepositoryConfig: tfvars.InfraCloudbuildV2RepositoryConfig,
		WorkerPoolID:                 tfvars.WorkerPoolID,
		AccessLevelName:              tfvars.AccessLevelName,
		ServicePerimeterName:         tfvars.ServicePerimeterName,
		ServicePerimeterMode:         tfvars.ServicePerimeterMode,
		LoggingBucket:                tfvars.LoggingBucket,
		BucketKMSKey:                 tfvars.BucketKMSKey,
		AttestationKMSProject:        kmsProject,
		OrgID:                        tfvars.OrgID,
	}

	err := utils.WriteTfvars(filepath.Join(c.EABPath, BootstrapStep, "terraform.tfvars"), bootstrapTfvars)
	if err != nil {
		return err
	}

	terraformDir := filepath.Join(c.EABPath, BootstrapStep)
	options := &terraform.Options{
		TerraformDir:       terraformDir,
		Logger:             c.Logger,
		NoColor:            true,
		MaxRetries:         MaxErrorRetries,
		TimeBetweenRetries: TimeBetweenErrorRetries,
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

	workerPoolInfo, err := extractInfoWithRegex(tfvars.WorkerPoolID, `projects/(?P<project>[^/]+)/locations/(?P<location>[^/]+)/workerPools/(?P<workerPool>[^/]+)`)
	if err != nil {
		fmt.Printf("# error extracting info for private workerpool. %v \n", err)
		return err
	}
	multitenantTfvars := MultiTenantTfvars{
		Envs:                         tfvars.Envs,
		Apps:                         tfvars.Apps,
		ServicePerimeterName:         tfvars.ServicePerimeterName,
		ServicePerimeterMode:         *tfvars.ServicePerimeterMode,
		CBPrivateWorkerpoolProjectID: workerPoolInfo["project"],
		AccessLevelName:              tfvars.AccessLevelName,
		DeletionProtection:           tfvars.DeletionProtection,
	}
	err = utils.WriteTfvars(filepath.Join(c.EABPath, MultitenantStep, "terraform.tfvars"), multitenantTfvars)
	if err != nil {
		return err
	}

	repoConfig := tfvars.InfraCloudbuildV2RepositoryConfig
	multitenantRepo := repoConfig.Repositories["multitenant"]
	gitPath := filepath.Join(c.CheckoutPath, multitenantRepo.RepositoryName)
	conf := utils.GitClone(t, repoConfig.RepoType, multitenantRepo.RepositoryName, multitenantRepo.RepositoryURL, gitPath, outputs.ProjectID, c.Logger)

	stageConf := StageConf{
		Stage:         tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryName,
		CICDProject:   outputs.ProjectID,
		Step:          MultitenantStep,
		Repo:          tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["multitenant"].RepositoryName,
		StageSA:       outputs.CBServiceAccountsEmails["multitenant"],
		GitConf:       conf,
		Envs:          slices.Collect(maps.Keys(tfvars.Envs)),
		DefaultRegion: tfvars.TriggerLocation,
	}

	return deployStage(t, stageConf, s, c)
}

func DeployFleetscopeStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {

	fleetscopeTfvars := FleetscopeTfvars{
		RemoteStateBucket:           outputs.StateBucket,
		NamespaceIDs:                tfvars.NamespaceIDs,
		ConfigSyncSecretType:        tfvars.ConfigSyncSecretType,
		ConfigSyncRepositoryURL:     tfvars.ConfigSyncRepositoryURL,
		DisableIstioOnNamespaces:    tfvars.DisableIstioOnNamespaces,
		ConfigSyncPolicyDir:         tfvars.ConfigSyncPolicyDir,
		ConfigSyncBranch:            tfvars.ConfigSyncBranch,
		AttestationKMSKey:           tfvars.AttestationKMSKey,
		AttestationEvaluationMode:   tfvars.AttestationEvaluationMode,
		EnableKueue:                 tfvars.EnableKueue,
		EnableMulticlusterDiscovery: tfvars.EnableMulticlusterDiscovery,
	}
	err := utils.WriteTfvars(filepath.Join(c.EABPath, FleetscopeStep, "terraform.tfvars"), fleetscopeTfvars)
	if err != nil {
		return err
	}

	repoConfig := tfvars.InfraCloudbuildV2RepositoryConfig
	fleetscopeRepo := repoConfig.Repositories["fleetscope"]
	gitPath := filepath.Join(c.CheckoutPath, fleetscopeRepo.RepositoryName)
	conf := utils.GitClone(t, repoConfig.RepoType, fleetscopeRepo.RepositoryName, fleetscopeRepo.RepositoryURL, gitPath, outputs.ProjectID, c.Logger)

	stageConf := StageConf{
		Stage:         tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryName,
		CICDProject:   outputs.ProjectID,
		Step:          FleetscopeStep,
		Repo:          tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["fleetscope"].RepositoryName,
		StageSA:       outputs.CBServiceAccountsEmails["fleetscope"],
		GitConf:       conf,
		Envs:          slices.Collect(maps.Keys(tfvars.Envs)),
		DefaultRegion: tfvars.TriggerLocation,
	}

	return deployStage(t, stageConf, s, c)
}

func DeployAppFactoryStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs BootstrapOutputs, c CommonConf) error {

	var kmsProject *string
	if tfvars.BucketKMSKey != nil {
		kmsInfo, err := extractInfoWithRegex(*tfvars.BucketKMSKey, `projects/(?P<project>[^/]+)/locations/(?P<location>[^/]+)/keyRings/(?P<keyRing>[^/]+)/cryptoKeys/(?P<cryptoKey>[^/]+)`)
		if err != nil {
			fmt.Printf("# error extracting info for BUCKET KMS PROJECT. %v \n", err)
		}
		if len(kmsInfo) > 0 {
			auxProject := kmsInfo["project"]
			kmsProject = &auxProject
		}
	}
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
		CloudbuildV2RepositoryConfig: tfvars.InfraCloudbuildV2RepositoryConfig,
		KMSProjectID:                 kmsProject,
		ServicePerimeterName:         tfvars.ServicePerimeterName,
		ServicePerimeterMode:         *tfvars.ServicePerimeterMode,
		InfraProjectAPIs:             tfvars.InfraProjectAPIs,
	}
	err := utils.WriteTfvars(filepath.Join(c.EABPath, AppFactoryStep, "terraform.tfvars"), appFactory)
	if err != nil {
		return err
	}

	repoConfig := tfvars.InfraCloudbuildV2RepositoryConfig
	appFactoryRepo := repoConfig.Repositories["applicationfactory"]
	gitPath := filepath.Join(c.CheckoutPath, appFactoryRepo.RepositoryName)
	conf := utils.GitClone(t, repoConfig.RepoType, appFactoryRepo.RepositoryName, appFactoryRepo.RepositoryURL, gitPath, outputs.ProjectID, c.Logger)

	stageConf := StageConf{
		Stage:         tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName,
		StageSA:       outputs.CBServiceAccountsEmails["applicationfactory"],
		CICDProject:   outputs.ProjectID,
		Step:          AppFactoryStep,
		Repo:          tfvars.InfraCloudbuildV2RepositoryConfig.Repositories["applicationfactory"].RepositoryName,
		GitConf:       conf,
		HasLocalStep:  true,
		LocalSteps:    []string{"shared"},
		Envs:          []string{"shared"},
		GroupingUnits: []string{"envs"},
		DefaultRegion: tfvars.TriggerLocation,
	}
	return deployStage(t, stageConf, s, c)
}

func DeployAppInfraStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, bootstrapOutputs BootstrapOutputs, outputs AppFactoryOutputs, c CommonConf) error {
	//for each environment

	appInfraTfvars := AppInfraTfvars{
		Region:                       tfvars.Region,
		BucketsForceDestroy:          tfvars.BucketForceDestroy,
		RemoteStateBucket:            bootstrapOutputs.StateBucket,
		EnvironmentNames:             slices.Collect(maps.Keys(tfvars.Envs)),
		CloudbuildV2RepositoryConfig: tfvars.AppServicesCloudbuildV2RepositoryConfig,
		AccessLevelName:              tfvars.AccessLevelName,
		LoggingBucket:                tfvars.LoggingBucket,
		BucketKMSKey:                 tfvars.BucketKMSKey,
		AttestationKMSKey:            tfvars.AttestationKMSKey,
		BucketPrefix:                 tfvars.BucketPrefix,
	}

	var err error
	for exampleName, services := range tfvars.Applications {
		for serviceName := range services {
			appGroupIndex := fmt.Sprintf("%s.%s", exampleName, serviceName)
			envs := []string{"shared"}
			if len(outputs.AppGroup[appGroupIndex].AppInfraProjectIDs) > 0 {
				envs = append(envs, slices.Collect(maps.Keys(tfvars.Envs))...)
			}

			err := utils.WriteTfvars(filepath.Join(c.EABPath, AppInfraStep, "apps", exampleName, serviceName, "envs", "shared", "terraform.tfvars"), appInfraTfvars)
			if err != nil {
				return err
			}

			for _, env := range envs {
				err = utils.ReplaceStringInFile(filepath.Join(c.EABPath, AppInfraStep, "apps", exampleName, serviceName, "envs", env, "backend.tf"), "UPDATE_INFRA_REPO_STATE", strings.SplitAfter(outputs.AppGroup[appGroupIndex].AppCloudbuildWorkspaceStateBucketName, "https://www.googleapis.com/storage/v1/b/")[1])
				if err != nil {
					return err
				}
			}

			repoConfig := tfvars.InfraCloudbuildV2RepositoryConfig
			serviceRepo := repoConfig.Repositories[serviceName]
			gitPath := filepath.Join(c.CheckoutPath, serviceRepo.RepositoryName)
			conf := utils.GitClone(t, repoConfig.RepoType, serviceRepo.RepositoryName, serviceRepo.RepositoryURL, gitPath, outputs.AppGroup[appGroupIndex].AppAdminProjectID, c.Logger)

			serviceAccountID := strings.Split(outputs.AppGroup[appGroupIndex].AppCloudbuildWorkspaceCloudbuildSAEmail, "/")
			stageConf := StageConf{
				Stage:         tfvars.InfraCloudbuildV2RepositoryConfig.Repositories[serviceName].RepositoryName,
				StageSA:       serviceAccountID[len(serviceAccountID)-1],
				CICDProject:   outputs.AppGroup[appGroupIndex].AppAdminProjectID,
				Step:          AppInfraStep,
				Repo:          tfvars.InfraCloudbuildV2RepositoryConfig.Repositories[serviceName].RepositoryName,
				GitConf:       conf,
				HasLocalStep:  true,
				LocalSteps:    []string{"shared"},
				GroupingUnits: []string{fmt.Sprintf("apps/%s/%s/envs/", exampleName, serviceName)},
				Envs:          envs,
				DefaultRegion: tfvars.TriggerLocation,
			}

			err = deployStage(t, stageConf, s, c)
			if err != nil {
				return err
			}
		}
	}
	return err
}

func DeployAppSourceStage(t testing.TB, s steps.Steps, tfvars GlobalTFVars, outputs AppInfraOutputs, c CommonConf) error {

	var err error
	for _, repository := range tfvars.AppServicesCloudbuildV2RepositoryConfig.Repositories {

		gitPath := filepath.Join(c.CheckoutPath, outputs.ServiceRepositoryName)
		conf := utils.GitClone(t, tfvars.AppServicesCloudbuildV2RepositoryConfig.RepoType, repository.RepositoryName, repository.RepositoryURL, gitPath, outputs.ServiceRepositoryProjectID, c.Logger)

		stageConf := StageConf{
			Stage:         outputs.ServiceRepositoryName,
			CICDProject:   outputs.ServiceRepositoryProjectID,
			Step:          filepath.Join(AppSourceStep, "hello-world"),
			Repo:          outputs.ServiceRepositoryName,
			GitConf:       conf,
			DefaultRegion: tfvars.TriggerLocation,
			Envs:          slices.Collect(maps.Keys(tfvars.Envs)),
			SkipPlan:      true,
		}

		err = deployApp(t, stageConf, s, c)
		if err != nil {
			return err
		}
	}
	return err
}

func deployStage(t testing.TB, sc StageConf, s steps.Steps, c CommonConf) error {

	err := sc.GitConf.CheckoutBranch("plan")
	if err != nil {
		return err
	}

	err = s.RunStep(fmt.Sprintf("%s.copy-code", sc.Stage), func() error {
		return copyStepCode(t, sc.GitConf, c.EABPath, c.CheckoutPath, sc.Repo, sc.Step, sc.CustomTargetDirPath, sc.Envs)
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
				TerraformDir:       filepath.Join(filepath.Join(c.CheckoutPath, sc.Repo), bu, localStep),
				Logger:             c.Logger,
				NoColor:            true,
				MaxRetries:         MaxErrorRetries,
				TimeBetweenRetries: TimeBetweenErrorRetries,
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

func deployApp(t testing.TB, sc StageConf, s steps.Steps, c CommonConf) error {

	err := sc.GitConf.CheckoutBranch("main")
	if err != nil {
		return err
	}

	err = s.RunStep(fmt.Sprintf("%s.copy-code", sc.Stage), func() error {
		return copyAppSourceCode(t, sc.GitConf, c.EABPath, c.CheckoutPath, sc.Repo, sc.Step, sc.CustomTargetDirPath)
	})
	if err != nil {
		return err
	}

	err = s.RunStep(sc.Stage, func() error {
		return deployEnvApp(t, sc.GitConf, sc.CICDProject, sc.DefaultRegion, sc.Repo, "hello-world", sc.Envs)
	})
	if err != nil {
		return err
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

func copyAppSourceCode(t testing.TB, conf utils.GitRepo, EABPath, checkoutPath, repo, step, customPath string) error {
	gcpPath := filepath.Join(checkoutPath, repo)
	targetDir := gcpPath
	if customPath != "" {
		targetDir = filepath.Join(gcpPath, customPath)
	}
	err := utils.CopyDirectory(filepath.Join(EABPath, step), targetDir)
	return err
}

func copyStepCode(t testing.TB, conf utils.GitRepo, EABPath, checkoutPath, repo, step, customPath string, environmentNames []string) error {
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

	fileName := filepath.Join(gcpPath, ".gitignore")
	content := `### https://raw.github.com/github/gitignore/90f149de451a5433aebd94d02d11b0e28843a1af/Terraform.gitignore
# Local .terraform directories
*.terraform*
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*
# tf lock file
.terraform.lock.hcl
`
	file, err := os.Create(fileName)
	if err != nil {
		fmt.Printf("Error creating file: %v\n", err)
	}
	// Ensure the file is closed when the function exits.
	// This is crucial for releasing resources and flushing any buffered data.
	defer file.Close()

	// Write the string content to the file.
	// file.WriteString returns the number of bytes written and an error.
	_, err = file.WriteString(content)
	if err != nil {
		return err
	}
	err = utils.CopyFile(filepath.Join(EABPath, "build/tf-wrapper.sh"), filepath.Join(gcpPath, "tf-wrapper.sh"))
	if err != nil {
		return err
	}

	oldValue := "^(development|nonproduction|production|shared)$"
	newValue := fmt.Sprintf("^(%s)$", strings.Join(environmentNames, "|"))
	err = utils.ReplaceStringInFile(filepath.Join(gcpPath, "tf-wrapper.sh"), oldValue, newValue)
	if err != nil {
		return err
	}
	s, err := os.Stat(filepath.Join(gcpPath, "tf-wrapper.sh"))
	if err != nil {
		return err
	}
	permissions := s.Mode().Perm()
	newPermissions := permissions | 0111
	err = os.Chmod(filepath.Join(gcpPath, "tf-wrapper.sh"), newPermissions)
	if err != nil {
		return err
	}

	return nil
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

	return gcp.NewGCP().WaitBuildSuccess(t, project, region, repo, commitSha, fmt.Sprintf("Terraform %s plan build Failed.", repo), MaxBuildRetries, MaxErrorRetries, TimeBetweenErrorRetries)
}

func saveBootstrapCodeOnly(t testing.TB, sc StageConf, s steps.Steps, c CommonConf) error {

	err := sc.GitConf.CheckoutBranch("plan")
	if err != nil {
		return err
	}

	err = s.RunStep(fmt.Sprintf("%s.copy-code", sc.Stage), func() error {
		return copyStepCode(t, sc.GitConf, c.EABPath, c.CheckoutPath, sc.Repo, sc.Step, sc.CustomTargetDirPath, sc.Envs)
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

func deployEnvApp(t testing.TB, conf utils.GitRepo, project, region, repo, service string, envs []string) error {
	var err error

	err = conf.CommitFiles(fmt.Sprintf("Initialize %s repo", repo))
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

	err = gcp.NewGCP().WaitBuildSuccess(t, project, region, repo, commitSha, fmt.Sprintf("Build %s env %s build Failed.", repo, service), MaxBuildRetries, MaxErrorRetries, TimeBetweenErrorRetries)
	if err != nil {
		return err
	}

	err = gcp.NewGCP().WaitReleaseSuccess(t, project, region, service, commitSha[0:7], fmt.Sprintf("Deploy %s env %s build Failed.", repo, service), MaxBuildRetries)

	return err
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

	return gcp.NewGCP().WaitBuildSuccess(t, project, region, repo, commitSha, fmt.Sprintf("Terraform %s apply %s build Failed.", repo, environment), MaxBuildRetries, MaxErrorRetries, TimeBetweenErrorRetries)
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

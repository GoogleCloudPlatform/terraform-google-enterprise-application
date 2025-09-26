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
	"reflect"
	"strings"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/mitchellh/go-testing-interface"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/utils"
)

const (
	PoliciesRepo    = "gcp-policies"
	BootstrapRepo   = "gcp-bootstrap"
	BootstrapStep   = "1-bootstrap"
	MultitenantStep = "2-multitenant"
	FleetscopeStep  = "3-fleetscope"
	AppFactoryStep  = "4-appfactory"
	AppInfraStep    = "5-appinfra"
	AppSourceStep   = "6-appsource"
)

type CommonConf struct {
	EABPath          string
	CheckoutPath     string
	PolicyPath       string
	ValidatorProject string
	DisablePrompt    bool
	Logger           *logger.Logger
}

type StageConf struct {
	Stage               string
	StageSA             string
	CICDProject         string
	DefaultRegion       string
	Step                string
	Repo                string
	CustomTargetDirPath string
	GitConf             utils.GitRepo
	HasLocalStep        bool
	GroupingUnits       []string
	Envs                []string
	LocalSteps          []string
	SkipPlan            bool
}

type BootstrapOutputs struct {
	ProjectID                       string
	StateBucket                     string
	ArtifactsBucket                 map[string]string
	LogsBucket                      map[string]string
	SourceRepoURLs                  map[string]string
	CBServiceAccountsEmails         map[string]string
	TFProjectID                     string
	TFRepositoryName                string
	TFTagVersionTerraform           string
	CBPrivateWorkerpoolID           string
	BinaryAuthorizationImage        string
	BinaryAuthorizationRepositoryID string
}

type AppFactoryOutputs struct {
	AppGroup        map[string]AppGroupOutput `hcl:"app-group"`
	AppFoldersIDs   map[string]string         `hcl:"app-folders-ids"`
	TriggerLocation string                    `hcl:"trigger_location"`
}

type AppInfraOutputs struct {
	ServiceRepositoryName      string   `hcl:"service_repository_name"`
	ServiceRepositoryProjectID string   `hcl:"service_repository_project_id"`
	CloudDeployTargetsNames    []string `hcl:"clouddeploy_targets_names"`
}

type AppGroupOutput struct {
	AppInfraProjectIDs                        map[string]string `hcl:"app_infra_project_ids"`
	AppAdminProjectID                         string            `hcl:"app_admin_project_id"`
	AppInfraRepositoryName                    string            `hcl:"app_infra_repository_name"`
	AppInfraRepositoryURL                     string            `hcl:"app_infra_repository_url"`
	AppCloudbuildWorkspaceApplyTriggerID      string            `hcl:"app_cloudbuild_workspace_apply_trigger_id"`
	AppCloudbuildWorkspacePlanTriggerID       string            `hcl:"app_cloudbuild_workspace_plan_trigger_id"`
	AppCloudbuildWorkspaceArtifactsBucketName string            `hcl:"app_cloudbuild_workspace_artifacts_bucket_name"`
	AppCloudbuildWorkspaceLogsBucketName      string            `hcl:"app_cloudbuild_workspace_logs_bucket_name"`
	AppCloudbuildWorkspaceStateBucketName     string            `hcl:"app_cloudbuild_workspace_state_bucket_name"`
	AppCloudbuildWorkspaceCloudbuildSAEmail   string            `hcl:"app_cloudbuild_workspace_cloudbuild_sa_email"`
}

type GcpGroups struct {
	SecurityReviewer   string `cty:"security_reviewer"`
	NetworkViewer      string `cty:"network_viewer"`
	SccAdmin           string `cty:"scc_admin"`
	GlobalSecretsAdmin string `cty:"global_secrets_admin"`
	KmsAdmin           string `cty:"kms_admin"`
}

// GlobalTFVars contains all the configuration for the deploy
type GlobalTFVars struct {
	ProjectID                               string                                   `hcl:"project_id"`
	BucketPrefix                            string                                   `hcl:"bucket_prefix"`
	BucketForceDestroy                      bool                                     `hcl:"bucket_force_destroy"`
	Location                                string                                   `hcl:"location"`
	TriggerLocation                         string                                   `hcl:"trigger_location"`
	Envs                                    map[string]Env                           `hcl:"envs"`
	CommonFolderID                          string                                   `hcl:"common_folder_id"`
	InfraCloudbuildV2RepositoryConfig       CloudbuildV2RepositoryConfig             `hcl:"infra_cloudbuildv2_repository_config"`
	AppServicesCloudbuildV2RepositoryConfig CloudbuildV2RepositoryConfig             `hcl:"app_services_cloudbuildv2_repository_config"`
	WorkerPoolID                            string                                   `hcl:"workerpool_id"`
	AccessLevelName                         string                                   `hcl:"access_level_name"`
	ServicePerimeterName                    string                                   `hcl:"service_perimeter_name"`
	ServicePerimeterMode                    string                                   `hcl:"service_perimeter_mode"`
	LoggingBucket                           string                                   `hcl:"logging_bucket"`
	BucketKMSKey                            string                                   `hcl:"bucket_kms_key"`
	AttestationKMSProject                   string                                   `hcl:"attestation_kms_project"`
	OrgID                                   string                                   `hcl:"org_id"`
	Apps                                    map[string]App                           `hcl:"apps"`
	CBPrivateWorkerpoolProjectID            string                                   `hcl:"cb_private_workerpool_project_id"`
	DeletionProtection                      bool                                     `hcl:"deletion_protection"`
	NamespaceIDs                            map[string]string                        `hcl:"namespace_ids"`
	RemoteStateBucket                       string                                   `hcl:"remote_state_bucket"`
	ConfigSyncSecretType                    string                                   `hcl:"config_sync_secret_type"`
	ConfigSyncRepositoryURL                 string                                   `hcl:"config_sync_repository_url"`
	DisableIstioOnNamespaces                []string                                 `hcl:"disable_istio_on_namespaces"`
	ConfigSyncPolicyDir                     string                                   `hcl:"config_sync_policy_dir"`
	ConfigSyncBranch                        string                                   `hcl:"config_sync_branch"`
	AttestationKMSKey                       string                                   `hcl:"attestation_kms_key"`
	AttestationEvaluationMode               string                                   `hcl:"attestation_evaluation_mode"`
	EnableKueue                             bool                                     `hcl:"enable_kueue"`
	BillingAccount                          string                                   `hcl:"billing_account"`
	Applications                            map[string]map[string]ApplicationService `hcl:"applications"`
	KMSProjectID                            string                                   `hcl:"kms_project_id"`
	InfraProjectAPIs                        []string                                 `hcl:"infra_project_apis"`
	Region                                  string                                   `hcl:"region"`
	BucketsForceDestroy                     bool                                     `hcl:"buckets_force_destroy"`
	EABCodePath                             string                                   `hcl:"eab_code_path"`
	CodeCheckoutPath                        string                                   `hcl:"code_checkout_path"`
}

type Env struct {
	BillingAccount   string   `hcl:"billing_account" cty:"billing_account"`
	FolderID         string   `hcl:"folder_id" cty:"folder_id"`
	NetworkProjectID string   `hcl:"network_project_id" cty:"network_project_id"`
	NetworkSelfLink  string   `hcl:"network_self_link" cty:"network_self_link"`
	OrgID            string   `hcl:"org_id" cty:"org_id"`
	SubnetsSelfLinks []string `hcl:"subnets_self_links" cty:"subnets_self_links"`
}

type CloudbuildV2RepositoryConfig struct {
	RepoType                               string                `hcl:"repo_type" cty:"repo_type"`
	Repositories                           map[string]Repository `hcl:"repositories" cty:"repositories"`
	GithubSecretID                         string                `hcl:"github_secret_id" cty:"github_secret_id"`
	GithubAppIDSecretID                    string                `hcl:"github_app_id_secret_id" cty:"github_app_id_secret_id"`
	GitlabReadAuthorizerCredentialSecretID string                `hcl:"gitlab_read_authorizer_credential_secret_id" cty:"gitlab_read_authorizer_credential_secret_id"`
	GitlabAuthorizerCredentialSecretID     string                `hcl:"gitlab_authorizer_credential_secret_id" cty:"gitlab_authorizer_credential_secret_id"`
	GitlabWebhookSecretID                  string                `hcl:"gitlab_webhook_secret_id" cty:"gitlab_webhook_secret_id"`
	GitlabEnterpriseHostURI                string                `hcl:"gitlab_enterprise_host_uri" cty:"gitlab_enterprise_host_uri"`
	GitlabEnterpriseServiceDirectory       string                `hcl:"gitlab_enterprise_service_directory" cty:"gitlab_enterprise_service_directory"`
	GitlabEnterpriseCACertificate          string                `hcl:"gitlab_enterprise_ca_certificate" cty:"gitlab_enterprise_ca_certificate"`
	SecretProjectID                        string                `hcl:"secret_project_id" cty:"secret_project_id"`
}

type Repository struct {
	RepositoryName string `hcl:"repository_name" cty:"repository_name"`
	RepositoryURL  string `hcl:"repository_url" cty:"repository_url"`
}

type App struct {
	Acronym        string              `hcl:"acronym" cty:"acronym"`
	IPAddressNames []string            `hcl:"ip_address_names" cty:"ip_address_names"`
	Certificates   map[string][]string `hcl:"certificates" cty:"certificates"`
}

type ApplicationService struct {
	AdminProjectID     string `hcl:"admin_project_id" cty:"admin_project_id"`
	CreateInfraProject bool   `hcl:"create_infra_project" cty:"create_infra_project"`
	CreateAdminProject bool   `hcl:"create_admin_project" cty:"create_admin_project"`
}

// CheckString checks if any of the string fields in the GlobalTFVars has the given string
func (g GlobalTFVars) CheckString(s string) {
	f := reflect.ValueOf(g)
	for i := 0; i < f.NumField(); i++ {
		if f.Field(i).Kind() == reflect.String && strings.Contains(f.Field(i).String(), s) {
			fmt.Printf("# Replace value '%s' for input '%s'\n", s, f.Type().Field(i).Tag.Get("hcl"))
		}
	}
}

type BootstrapTfvars struct {
	ProjectID                    string                       `hcl:"project_id"`
	BucketPrefix                 string                       `hcl:"bucket_prefix"`
	BucketForceDestroy           bool                         `hcl:"bucket_force_destroy"`
	Location                     string                       `hcl:"location"`
	TriggerLocation              string                       `hcl:"trigger_location"`
	TFApplyBranches              []string                     `hcl:"tf_apply_branches"`
	Envs                         map[string]Env               `hcl:"envs"`
	CommonFolderID               string                       `hcl:"common_folder_id"`
	CloudbuildV2RepositoryConfig CloudbuildV2RepositoryConfig `hcl:"cloudbuildv2_repository_config"`
	WorkerPoolID                 string                       `hcl:"workerpool_id"`
	AccessLevelName              string                       `hcl:"access_level_name"`
	ServicePerimeterName         string                       `hcl:"service_perimeter_name"`
	ServicePerimeterMode         string                       `hcl:"service_perimeter_mode"`
	LoggingBucket                string                       `hcl:"logging_bucket"`
	BucketKMSKey                 string                       `hcl:"bucket_kms_key"`
	AttestationKMSProject        string                       `hcl:"attestation_kms_project"`
	OrgID                        string                       `hcl:"org_id"`
}

type MultiTenantTfvars struct {
	Envs                         map[string]Env `hcl:"envs"`
	Apps                         map[string]App `hcl:"apps"`
	ServicePerimeterName         string         `hcl:"service_perimeter_name"`
	ServicePerimeterMode         string         `hcl:"service_perimeter_mode"`
	CBPrivateWorkerpoolProjectID string         `hcl:"cb_private_workerpool_project_id"`
	AccessLevelName              string         `hcl:"access_level_name"`
	DeletionProtection           bool           `hcl:"deletion_protection"`
}

type FleetscopeTfvars struct {
	NamespaceIDs              map[string]string `hcl:"namespace_ids"`
	RemoteStateBucket         string            `hcl:"remote_state_bucket"`
	ConfigSyncSecretType      string            `hcl:"config_sync_secret_type"`
	ConfigSyncRepositoryURL   string            `hcl:"config_sync_repository_url"`
	DisableIstioOnNamespaces  []string          `hcl:"disable_istio_on_namespaces"`
	ConfigSyncPolicyDir       string            `hcl:"config_sync_policy_dir"`
	ConfigSyncBranch          string            `hcl:"config_sync_branch"`
	AttestationKMSKey         string            `hcl:"attestation_kms_key"`
	AttestationEvaluationMode string            `hcl:"attestation_evaluation_mode"`
	EnableKueue               bool              `hcl:"enable_kueue"`
}

type AppFactoryTfvars struct {
	CommonFolderID               string                                   `hcl:"common_folder_id"`
	OrgID                        string                                   `hcl:"org_id"`
	BillingAccount               string                                   `hcl:"billing_account"`
	Envs                         map[string]Env                           `hcl:"envs"`
	BucketPrefix                 string                                   `hcl:"bucket_prefix"`
	BucketForceDestroy           bool                                     `hcl:"bucket_force_destroy"`
	Location                     string                                   `hcl:"location"`
	TriggerLocation              string                                   `hcl:"trigger_location"`
	TFApplyBranches              []string                                 `hcl:"tf_apply_branches"`
	RemoteStateBucket            string                                   `hcl:"remote_state_bucket"`
	Applications                 map[string]map[string]ApplicationService `hcl:"applications"`
	CloudbuildV2RepositoryConfig CloudbuildV2RepositoryConfig             `hcl:"cloudbuildv2_repository_config"`
	KMSProjectID                 string                                   `hcl:"kms_project_id"`
	ServicePerimeterName         string                                   `hcl:"service_perimeter_name"`
	ServicePerimeterMode         string                                   `hcl:"service_perimeter_mode"`
	InfraProjectAPIs             []string                                 `hcl:"infra_project_apis"`
}

type AppInfraTfvars struct {
	Region                       string                       `hcl:"region"`
	BucketsForceDestroy          bool                         `hcl:"buckets_force_destroy"`
	RemoteStateBucket            string                       `hcl:"remote_state_bucket"`
	EnvironmentNames             []string                     `hcl:"environment_names"`
	CloudbuildV2RepositoryConfig CloudbuildV2RepositoryConfig `hcl:"cloudbuildv2_repository_config"`
	AccessLevelName              string                       `hcl:"access_level_name"`
	LoggingBucket                string                       `hcl:"logging_bucket"`
	BucketKMSKey                 string                       `hcl:"bucket_kms_key"`
	AttestationKMSKey            string                       `hcl:"attestation_kms_key"`
}

func GetBootstrapStepOutputs(t testing.TB, eabPath string) BootstrapOutputs {
	options := &terraform.Options{
		TerraformDir: filepath.Join(eabPath, "1-bootstrap"),
		Logger:       logger.Discard,
		NoColor:      true,
	}
	return BootstrapOutputs{
		ProjectID:                       terraform.Output(t, options, "project_id"),
		StateBucket:                     terraform.Output(t, options, "state_bucket"),
		ArtifactsBucket:                 terraform.OutputMap(t, options, "artifacts_bucket"),
		LogsBucket:                      terraform.OutputMap(t, options, "logs_bucket"),
		SourceRepoURLs:                  terraform.OutputMap(t, options, "source_repo_urls"),
		CBServiceAccountsEmails:         terraform.OutputMap(t, options, "cb_service_accounts_emails"),
		TFProjectID:                     terraform.Output(t, options, "tf_project_id"),
		TFRepositoryName:                terraform.Output(t, options, "tf_repository_name"),
		TFTagVersionTerraform:           terraform.Output(t, options, "tf_tag_version_terraform"),
		CBPrivateWorkerpoolID:           terraform.Output(t, options, "cb_private_workerpool_id"),
		BinaryAuthorizationImage:        terraform.Output(t, options, "binary_authorization_image"),
		BinaryAuthorizationRepositoryID: terraform.Output(t, options, "binary_authorization_repository_id"),
	}
}

func GetAppInfraStepOutputs(t testing.TB, eabPath string) AppInfraOutputs {
	options := &terraform.Options{
		TerraformDir: filepath.Join(eabPath, "apps/default-example/hello-world/envs/shared"),
		Logger:       logger.Discard,
		NoColor:      true,
	}
	terraform.Init(t, options)
	t.Logf("Getting outputs from %s", options.TerraformDir)
	return AppInfraOutputs{
		ServiceRepositoryName:      terraform.Output(t, options, "service_repository_name"),
		ServiceRepositoryProjectID: terraform.Output(t, options, "service_repository_project_id"),
		CloudDeployTargetsNames:    terraform.OutputList(t, options, "clouddeploy_targets_names"),
	}
}

func convertToAppFactoryOutputs(input map[string]interface{}) (AppFactoryOutputs, error) {
	outputs := AppFactoryOutputs{
		AppGroup:      make(map[string]AppGroupOutput),
		AppFoldersIDs: make(map[string]string),
	}

	//Handle TriggerLocation
	if triggerLocation, ok := input["trigger_location"].(string); ok {
		outputs.TriggerLocation = triggerLocation
	} else {
		return AppFactoryOutputs{}, fmt.Errorf("expected trigger_location to be string, got %T", input["trigger_location"])
	}

	// Handle AppFoldersIDs
	if appFoldersIDs, ok := input["app-folders-ids"].(map[string]interface{}); ok {
		for k, v := range appFoldersIDs {
			if strVal, ok := v.(string); ok {
				outputs.AppFoldersIDs[k] = strVal
			} else {
				return AppFactoryOutputs{}, fmt.Errorf("expected app-folders-ids[%s] to be string, got %T", k, v)
			}
		}
	} else {
		return AppFactoryOutputs{}, fmt.Errorf("expected app-folders-ids to be map[string]interface{}, got %T", input["app-folders-ids"])
	}

	// Handle AppGroup
	if appGroup, ok := input["app-group"].(map[string]interface{}); ok {
		for componentName, componentData := range appGroup {
			componentDataMap, ok := componentData.(map[string]interface{})
			if !ok {
				return AppFactoryOutputs{}, fmt.Errorf("expected app-group[%s] to be map[string]interface{}, got %T", componentName, componentData)
			}

			// Create a new AppGroupOutput
			appGroupOutput := AppGroupOutput{
				AppInfraProjectIDs: make(map[string]string),
			}

			// Populate AppGroupOutput fields from componentDataMap
			for key, value := range componentDataMap {
				switch key {
				case "app_infra_project_ids":
					if appInfraProjectIDs, ok := value.(map[string]interface{}); ok {
						for k, v := range appInfraProjectIDs {
							if strVal, ok := v.(string); ok {
								appGroupOutput.AppInfraProjectIDs[k] = strVal
							} else {
								return AppFactoryOutputs{}, fmt.Errorf("expected app_infra_project_ids[%s] to be string, got %T", k, v)
							}
						}
					} else {
						return AppFactoryOutputs{}, fmt.Errorf("expected app_infra_project_ids to be map[string]interface{}, got %T", value)
					}
				case "app_admin_project_id":
					if strVal, ok := value.(string); ok {
						appGroupOutput.AppAdminProjectID = strVal
					} else {
						return AppFactoryOutputs{}, fmt.Errorf("expected app_admin_project_id to be string, got %T", value)
					}
				case "app_infra_repository_name":
					if strVal, ok := value.(string); ok {
						appGroupOutput.AppInfraRepositoryName = strVal
					} else {
						return AppFactoryOutputs{}, fmt.Errorf("expected app_infra_repository_name to be string, got %T", value)
					}
				case "app_infra_repository_url":
					if strVal, ok := value.(string); ok {
						appGroupOutput.AppInfraRepositoryURL = strVal
					} else {
						return AppFactoryOutputs{}, fmt.Errorf("expected app_infra_repository_url to be string, got %T", value)
					}
				case "app_cloudbuild_workspace_apply_trigger_id":
					if strVal, ok := value.(string); ok {
						appGroupOutput.AppCloudbuildWorkspaceApplyTriggerID = strVal
					} else {
						return AppFactoryOutputs{}, fmt.Errorf("expected app_cloudbuild_workspace_apply_trigger_id to be string, got %T", value)
					}
				case "app_cloudbuild_workspace_plan_trigger_id":
					if strVal, ok := value.(string); ok {
						appGroupOutput.AppCloudbuildWorkspacePlanTriggerID = strVal
					} else {
						return AppFactoryOutputs{}, fmt.Errorf("expected app_cloudbuild_workspace_plan_trigger_id to be string, got %T", value)
					}
				case "app_cloudbuild_workspace_artifacts_bucket_name":
					if strVal, ok := value.(string); ok {
						appGroupOutput.AppCloudbuildWorkspaceArtifactsBucketName = strVal
					} else {
						return AppFactoryOutputs{}, fmt.Errorf("expected app_cloudbuild_workspace_artifacts_bucket_name to be string, got %T", value)
					}
				case "app_cloudbuild_workspace_logs_bucket_name":
					if strVal, ok := value.(string); ok {
						appGroupOutput.AppCloudbuildWorkspaceLogsBucketName = strVal
					} else {
						return AppFactoryOutputs{}, fmt.Errorf("expected app_cloudbuild_workspace_logs_bucket_name to be string, got %T", value)
					}
				case "app_cloudbuild_workspace_state_bucket_name":
					if strVal, ok := value.(string); ok {
						appGroupOutput.AppCloudbuildWorkspaceStateBucketName = strVal
					} else {
						return AppFactoryOutputs{}, fmt.Errorf("expected app_cloudbuild_workspace_state_bucket_name to be string, got %T", value)
					}
				case "app_cloudbuild_workspace_cloudbuild_sa_email":
					if strVal, ok := value.(string); ok {
						appGroupOutput.AppCloudbuildWorkspaceCloudbuildSAEmail = strVal
					} else {
						return AppFactoryOutputs{}, fmt.Errorf("expected app_cloudbuild_workspace_cloudbuild_sa_email to be string, got %T", value)
					}
				// Add cases for other fields as needed
				default:
					fmt.Printf("Warning: Unhandled field %s\n", key)
				}
			}

			// Add the converted AppGroupOutput to the outputs.AppGroup map
			outputs.AppGroup[componentName] = appGroupOutput
		}
	} else {
		return AppFactoryOutputs{}, fmt.Errorf("expected app-group to be map[string]interface{}, got %T", input["app-group"])
	}

	return outputs, nil
}

func GetAppFactoryStepOutputs(t testing.TB, eabPath string) AppFactoryOutputs {
	options := &terraform.Options{
		TerraformDir: filepath.Join(eabPath, "envs/shared"),
		Logger:       logger.Discard,
		NoColor:      true,
	}

	output, err := convertToAppFactoryOutputs(terraform.OutputAll(t, options))
	if err != nil {
		return AppFactoryOutputs{}
	}

	return output
}

// ReadGlobalTFVars reads the tfvars file that has all the configuration for the deploy
func ReadGlobalTFVars(file string) (GlobalTFVars, error) {
	var globalTfvars GlobalTFVars
	if file == "" {
		return globalTfvars, fmt.Errorf("tfvars file is required")
	}
	_, err := os.Stat(file)
	if os.IsNotExist(err) {
		return globalTfvars, fmt.Errorf("tfvars file '%s' does not exits\n", file)
	}
	err = utils.ReadTfvars(file, &globalTfvars)
	if err != nil {
		return globalTfvars, fmt.Errorf("Failed to load tfvars file %s. Error: %s\n", file, err.Error())
	}
	return globalTfvars, nil
}

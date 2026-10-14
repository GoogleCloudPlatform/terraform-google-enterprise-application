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
	"encoding/json"
	"fmt"
	"os"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/utils"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/mitchellh/go-testing-interface"
)

// CommonConf has the configuration that is common for all stages
type CommonConf struct {
	EABPath          string
	CheckoutPath     string
	PolicyPath       string
	ValidatorProject string
	DisablePrompt    bool
	Logger           *logger.Logger
	ExampleName      string
}

// GlobalTFVars contains all the configuration for the deploy
type GlobalTFVars struct {
	ProjectID                       string                        `hcl:"project_id"`
	Region                          string                        `hcl:"region"`
	NetworkID                       *string                       `hcl:"network_id,optional"`
	SubnetworkSelfLink              *string                       `hcl:"subnetwork_self_link,optional"`
	WorkerPoolID                    *string                       `hcl:"workerpool_id,optional"`
	LoggingBucket                   *string                       `hcl:"logging_bucket,optional"`
	BucketKMSKey                    *string                       `hcl:"bucket_kms_key,optional"`
	ServicePerimeterName            *string                       `hcl:"service_perimeter_name,optional"`
	ServicePerimeterMode            *string                       `hcl:"service_perimeter_mode,optional"`
	AccessLevelName                 *string                       `hcl:"access_level_name,optional"`
	AttestationKMSKey               *string                       `hcl:"attestation_kms_key,optional"`
	BinaryAuthorizationImage        *string                       `hcl:"binary_authorization_image,optional"`
	BinaryAuthorizationRepositoryID *string                       `hcl:"binary_authorization_repository_id,optional"`
	CreateNat                       *bool                         `hcl:"create_nat,optional"`
	EnablesNetworkConnection        *bool                         `hcl:"enables_network_connection_and_peering_routes,optional"`
	NCCConfig                       *NCCConfig                    `hcl:"ncc_config,optional"`
	Teams                           map[string]string             `hcl:"teams,optional"`
	CloudbuildV2RepositoryConfig    *CloudbuildV2RepositoryConfig `hcl:"cloudbuildv2_repository_config,optional"`
	EABCodePath                     string                        `hcl:"eab_code_path"`
	CodeCheckoutPath                string                        `hcl:"code_checkout_path"`
}

type NCCConfig struct {
	EnableNCC                *bool             `hcl:"enable_ncc,optional" cty:"enable_ncc"`
	HubURI                   *string           `hcl:"hub_uri,optional" cty:"hub_uri"`
	SpokeGroup               *string           `hcl:"spoke_group,optional" cty:"spoke_group"`
	SpokeName                *string           `hcl:"spoke_name,optional" cty:"spoke_name"`
	SpokeDescription         *string           `hcl:"spoke_description,optional" cty:"spoke_description"`
	SpokeLabels              map[string]string `hcl:"spoke_labels,optional" cty:"spoke_labels"`
	SpokeExcludeExportRanges []string          `hcl:"spoke_exclude_export_ranges,optional" cty:"spoke_exclude_export_ranges"`
	SpokeIncludeExportRanges []string          `hcl:"spoke_include_export_ranges,optional" cty:"spoke_include_export_ranges"`
}

type CloudbuildV2RepositoryConfig struct {
	RepoType                               string                `hcl:"repo_type" cty:"repo_type"`
	Repositories                           map[string]Repository `hcl:"repositories" cty:"repositories"`
	GithubSecretID                         *string               `hcl:"github_secret_id,optional" cty:"github_secret_id"`
	GithubAppIDSecretID                    *string               `hcl:"github_app_id_secret_id,optional" cty:"github_app_id_secret_id"`
	GitlabReadAuthorizerCredentialSecretID *string               `hcl:"gitlab_read_authorizer_credential_secret_id,optional" cty:"gitlab_read_authorizer_credential_secret_id"`
	GitlabAuthorizerCredentialSecretID     *string               `hcl:"gitlab_authorizer_credential_secret_id,optional" cty:"gitlab_authorizer_credential_secret_id"`
	GitlabWebhookSecretID                  *string               `hcl:"gitlab_webhook_secret_id,optional" cty:"gitlab_webhook_secret_id"`
	GitlabEnterpriseHostURI                *string               `hcl:"gitlab_enterprise_host_uri,optional" cty:"gitlab_enterprise_host_uri"`
	GitlabEnterpriseServiceDirectory       *string               `hcl:"gitlab_enterprise_service_directory,optional" cty:"gitlab_enterprise_service_directory"`
	GitlabEnterpriseCACertificate          *string               `hcl:"gitlab_enterprise_ca_certificate,optional" cty:"gitlab_enterprise_ca_certificate"`
	SecretProjectID                        *string               `hcl:"secret_project_id,optional" cty:"secret_project_id"`
}

type Repository struct {
	RepositoryName string `hcl:"repository_name" cty:"repository_name"`
	RepositoryURL  string `hcl:"repository_url" cty:"repository_url"`
}

type AppInfraOutputs struct {
	ServiceRepositoryName      map[string]string   `hcl:"service_repository_name"`
	ServiceRepositoryProjectID map[string]string   `hcl:"service_repository_project_id"`
	CloudDeployTargetsNames    map[string][]string `hcl:"clouddeploy_targets_names"`
	AppSourceRepoURL           string              `hcl:"app_source_repo_url"`
	AppVersion                 string              `hcl:"app_version"`
}

func GetAppInfraStepOutputs(t testing.TB, standalonePath string) AppInfraOutputs {
	options := &terraform.Options{
		TerraformDir: standalonePath,
		Logger:       logger.Discard,
		NoColor:      true,
	}
	t.Logf("Getting outputs from %s", options.TerraformDir)

	repoNames := make(map[string]string)
	if out, err := terraform.OutputMapE(t, options, "service_repository_name"); err == nil {
		repoNames = out
	}

	repoProjects := make(map[string]string)
	if out, err := terraform.OutputMapE(t, options, "service_repository_project_id"); err == nil {
		repoProjects = out
	}

	deployTargets := make(map[string][]string)
	if outJSON, err := terraform.OutputJsonE(t, options, "clouddeploy_targets_names"); err == nil && outJSON != "" {
		_ = json.Unmarshal([]byte(outJSON), &deployTargets)
	}

	appSourceRepoURL := ""
	if out, err := terraform.OutputE(t, options, "app_source_repo_url"); err == nil {
		appSourceRepoURL = out
	}

	appVersion := ""
	if out, err := terraform.OutputE(t, options, "app_version"); err == nil {
		appVersion = out
	}

	return AppInfraOutputs{
		ServiceRepositoryName:      repoNames,
		ServiceRepositoryProjectID: repoProjects,
		CloudDeployTargetsNames:    deployTargets,
		AppSourceRepoURL:           appSourceRepoURL,
		AppVersion:                 appVersion,
	}
}

// ReadGlobalTFVars reads the tfvars file that has all the configuration for the deploy
func ReadGlobalTFVars(file string) (GlobalTFVars, error) {
	var globalTfvars GlobalTFVars
	if file == "" {
		return globalTfvars, fmt.Errorf("tfvars file is required")
	}
	_, err := os.Stat(file)
	if os.IsNotExist(err) {
		return globalTfvars, fmt.Errorf("tfvars file '%s' does not exist\n", file)
	}
	err = utils.ReadTfvars(file, &globalTfvars)
	if err != nil {
		return globalTfvars, fmt.Errorf("failed to load tfvars file %s. Error: %s\n", file, err.Error())
	}
	return globalTfvars, nil
}

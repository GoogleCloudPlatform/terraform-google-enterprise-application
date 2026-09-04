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
	ProjectID                        string                        `hcl:"project_id"`
	Region                           string                        `hcl:"region"`
	NetworkID                        *string                       `hcl:"network_id"`
	SubnetworkSelfLink               *string                       `hcl:"subnetwork_self_link"`
	WorkerPoolID                     *string                       `hcl:"workerpool_id"`
	LoggingBucket                    *string                       `hcl:"logging_bucket"`
	BucketKMSKey                     *string                       `hcl:"bucket_kms_key"`
	ServicePerimeterName             *string                       `hcl:"service_perimeter_name"`
	ServicePerimeterMode             *string                       `hcl:"service_perimeter_mode"`
	AccessLevelName                  *string                       `hcl:"access_level_name"`
	AttestationKMSKey                *string                       `hcl:"attestation_kms_key"`
	BinaryAuthorizationImage         *string                       `hcl:"binary_authorization_image"`
	BinaryAuthorizationRepositoryID  *string                       `hcl:"binary_authorization_repository_id"`
	CreateNat                        *bool                         `hcl:"create_nat"`
	EnablesNetworkConnection         *bool                         `hcl:"enables_network_connection_and_peering_routes"`
	Teams                            map[string]string             `hcl:"teams"`
	CloudbuildV2RepositoryConfig     *CloudbuildV2RepositoryConfig `hcl:"cloudbuildv2_repository_config"`
	EABCodePath                      string                        `hcl:"eab_code_path"`
	CodeCheckoutPath                 string                        `hcl:"code_checkout_path"`
}

type CloudbuildV2RepositoryConfig struct {
	RepoType                               string                `hcl:"repo_type" cty:"repo_type"`
	Repositories                           map[string]Repository `hcl:"repositories" cty:"repositories"`
	GithubSecretID                         *string               `hcl:"github_secret_id" cty:"github_secret_id"`
	GithubAppIDSecretID                    *string               `hcl:"github_app_id_secret_id" cty:"github_app_id_secret_id"`
	GitlabReadAuthorizerCredentialSecretID *string               `hcl:"gitlab_read_authorizer_credential_secret_id" cty:"gitlab_read_authorizer_credential_secret_id"`
	GitlabAuthorizerCredentialSecretID     *string               `hcl:"gitlab_authorizer_credential_secret_id" cty:"gitlab_authorizer_credential_secret_id"`
	GitlabWebhookSecretID                  *string               `hcl:"gitlab_webhook_secret_id" cty:"gitlab_webhook_secret_id"`
	GitlabEnterpriseHostURI                *string               `hcl:"gitlab_enterprise_host_uri" cty:"gitlab_enterprise_host_uri"`
	GitlabEnterpriseServiceDirectory       *string               `hcl:"gitlab_enterprise_service_directory" cty:"gitlab_enterprise_service_directory"`
	GitlabEnterpriseCACertificate          *string               `hcl:"gitlab_enterprise_ca_certificate" cty:"gitlab_enterprise_ca_certificate"`
	SecretProjectID                        *string               `hcl:"secret_project_id" cty:"secret_project_id"`
}

type Repository struct {
	RepositoryName string `hcl:"repository_name" cty:"repository_name"`
	RepositoryURL  string `hcl:"repository_url" cty:"repository_url"`
}

type AppInfraOutputs struct {
	ServiceRepositoryName      map[string]string   `hcl:"service_repository_name"`
	ServiceRepositoryProjectID map[string]string   `hcl:"service_repository_project_id"`
	CloudDeployTargetsNames    map[string][]string `hcl:"clouddeploy_targets_names"`
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

	return AppInfraOutputs{
		ServiceRepositoryName:      repoNames,
		ServiceRepositoryProjectID: repoProjects,
		CloudDeployTargetsNames:    deployTargets,
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

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
	"os/exec"
	"strings"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/gcp"
	"github.com/mitchellh/go-testing-interface"
)

var placeholderPatterns = []string{
	"REPLACE_ME",
	"YOUR_",
	"FULL_PATH_",
	"your-group@yourdomain.com",
}

func isPlaceholder(val string) bool {
	if val == "" {
		return false
	}
	for _, p := range placeholderPatterns {
		if strings.Contains(val, p) {
			return true
		}
	}
	return false
}

func isBlankOrPlaceholder(val string) bool {
	return strings.TrimSpace(val) == "" || isPlaceholder(val)
}

func ValidateBasicFields(t testing.TB, g GlobalTFVars) bool {
	fmt.Println("")
	fmt.Println("# Validating tfvar file.")
	valid := true

	if isBlankOrPlaceholder(g.ProjectID) {
		fmt.Println("# Invalid or placeholder value for required input 'project_id'")
		valid = false
	}
	if isBlankOrPlaceholder(g.Region) {
		fmt.Println("# Invalid or placeholder value for required input 'region'")
		valid = false
	}
	if isBlankOrPlaceholder(g.EABCodePath) {
		fmt.Println("# Invalid or placeholder value for required input 'eab_code_path'")
		valid = false
	} else {
		fi, err := os.Stat(g.EABCodePath)
		if err != nil || !fi.IsDir() {
			fmt.Printf("# The directory specified in 'eab_code_path' (%s) does not exist or is not a directory.\n", g.EABCodePath)
			valid = false
		}
	}
	if isBlankOrPlaceholder(g.CodeCheckoutPath) {
		fmt.Println("# Invalid or placeholder value for required input 'code_checkout_path'")
		valid = false
	}

	if g.CloudbuildV2RepositoryConfig == nil {
		fmt.Println("# Error: You must provide `cloudbuildv2_repository_config` in your tfvars file.")
		return false
	}

	repoType := g.CloudbuildV2RepositoryConfig.RepoType
	if repoType != "CSR" && repoType != "GITHUBv2" && repoType != "GITLABv2" {
		fmt.Printf("# Invalid 'repo_type' (%s). Supported types are 'CSR', 'GITHUBv2', and 'GITLABv2'.\n", repoType)
		valid = false
	}

	if repoType == "GITHUBv2" {
		if g.CloudbuildV2RepositoryConfig.GithubAppIDSecretID == nil || isBlankOrPlaceholder(*g.CloudbuildV2RepositoryConfig.GithubAppIDSecretID) ||
			g.CloudbuildV2RepositoryConfig.GithubSecretID == nil || isBlankOrPlaceholder(*g.CloudbuildV2RepositoryConfig.GithubSecretID) {
			fmt.Println("# You must provide valid 'github_app_id_secret_id' and 'github_secret_id' for GITHUBv2 repo_type.")
			valid = false
		}
	}

	if repoType == "GITLABv2" {
		if g.CloudbuildV2RepositoryConfig.GitlabAuthorizerCredentialSecretID == nil || isBlankOrPlaceholder(*g.CloudbuildV2RepositoryConfig.GitlabAuthorizerCredentialSecretID) ||
			g.CloudbuildV2RepositoryConfig.GitlabReadAuthorizerCredentialSecretID == nil || isBlankOrPlaceholder(*g.CloudbuildV2RepositoryConfig.GitlabReadAuthorizerCredentialSecretID) ||
			g.CloudbuildV2RepositoryConfig.GitlabWebhookSecretID == nil || isBlankOrPlaceholder(*g.CloudbuildV2RepositoryConfig.GitlabWebhookSecretID) {
			fmt.Println("# You must provide valid 'gitlab_authorizer_credential_secret_id', 'gitlab_webhook_secret_id' and 'gitlab_read_authorizer_credential_secret_id' for GITLABv2 repo_type.")
			valid = false
		}
	}

	if len(g.CloudbuildV2RepositoryConfig.Repositories) == 0 {
		fmt.Println("# You must provide at least one repository in 'cloudbuildv2_repository_config.repositories'.")
		valid = false
	} else {
		for key, repo := range g.CloudbuildV2RepositoryConfig.Repositories {
			if repoType == "GITHUBv2" || repoType == "GITLABv2" {
				if isBlankOrPlaceholder(repo.RepositoryURL) {
					fmt.Printf("# Repository '%s' must have a valid 'repository_url' for %s.\n", key, repoType)
					valid = false
				}
			}
		}
	}

	// Optional fields placeholder check
	if g.NetworkID != nil && isPlaceholder(*g.NetworkID) {
		fmt.Println("# Replace placeholder value in optional input 'network_id'")
		valid = false
	}
	if g.SubnetworkSelfLink != nil && isPlaceholder(*g.SubnetworkSelfLink) {
		fmt.Println("# Replace placeholder value in optional input 'subnetwork_self_link'")
		valid = false
	}
	if g.WorkerPoolID != nil && isPlaceholder(*g.WorkerPoolID) {
		fmt.Println("# Replace placeholder value in optional input 'workerpool_id'")
		valid = false
	}
	if g.AttestationKMSKey != nil && isPlaceholder(*g.AttestationKMSKey) {
		fmt.Println("# Replace placeholder value in optional input 'attestation_kms_key'")
		valid = false
	}
	if g.BinaryAuthorizationImage != nil && isPlaceholder(*g.BinaryAuthorizationImage) {
		fmt.Println("# Replace placeholder value in optional input 'binary_authorization_image'")
		valid = false
	}
	if g.BinaryAuthorizationRepositoryID != nil && isPlaceholder(*g.BinaryAuthorizationRepositoryID) {
		fmt.Println("# Replace placeholder value in optional input 'binary_authorization_repository_id'")
		valid = false
	}
	if g.BucketKMSKey != nil && isPlaceholder(*g.BucketKMSKey) {
		fmt.Println("# Replace placeholder value in optional input 'bucket_kms_key'")
		valid = false
	}
	if g.LoggingBucket != nil && isPlaceholder(*g.LoggingBucket) {
		fmt.Println("# Replace placeholder value in optional input 'logging_bucket'")
		valid = false
	}

	// VPC Service Controls consistency
	if g.ServicePerimeterName != nil && *g.ServicePerimeterName != "" && !isPlaceholder(*g.ServicePerimeterName) {
		if g.AccessLevelName == nil || isBlankOrPlaceholder(*g.AccessLevelName) {
			fmt.Println("# You must provide a valid 'access_level_name' when 'service_perimeter_name' is configured.")
			valid = false
		}
		if g.ServicePerimeterMode != nil && *g.ServicePerimeterMode != "ENFORCE" && *g.ServicePerimeterMode != "DRY_RUN" {
			fmt.Printf("# Invalid 'service_perimeter_mode' (%s). Supported modes are 'ENFORCE' and 'DRY_RUN'.\n", *g.ServicePerimeterMode)
			valid = false
		}
	}

	return valid
}

func ValidatePermissions(t testing.TB, g GlobalTFVars) bool {
	fmt.Println("")
	fmt.Println("# Validating if identity has required roles on project.")
	valid := true

	if isBlankOrPlaceholder(g.ProjectID) {
		fmt.Println("# Skipping IAM permissions check due to invalid or placeholder 'project_id'.")
		return false
	}

	projectRoles := map[string][]string{
		fmt.Sprintf("seedProject:%s", g.ProjectID): {
			"roles/cloudbuild.connectionAdmin",
			"roles/compute.networkAdmin",
			"roles/resourcemanager.projectIamAdmin",
		},
	}

	for key, roles := range projectRoles {
		project := strings.Split(key, ":")[1]
		fmt.Printf("# Checking role at project %s. \n", project)

		for _, role := range roles {
			rolePermissions, err := gcp.NewGCP().GetRolePermissions(t, role)
			if err != nil {
				fmt.Printf("# Error getting roles: %v\n", err)
				return false
			}

			cleanPermission := []string{}
			for _, permission := range rolePermissions {
				if permission != "resourcemanager.projects.list" && permission != "networksecurity.firewallEndpoints.create" &&
					permission != "networksecurity.firewallEndpoints.delete" && permission != "networksecurity.firewallEndpoints.get" &&
					permission != "networksecurity.firewallEndpoints.list" && permission != "networksecurity.firewallEndpoints.update" &&
					permission != "networksecurity.firewallEndpoints.use" {
					cleanPermission = append(cleanPermission, permission)
				}
			}

			identityPermissions, err := gcp.NewGCP().TestIamPermissions(t, fmt.Sprintf("projects/%s", project), cleanPermission)
			if err != nil {
				fmt.Printf("# Error testing permissions: %v\n", err)
				return false
			}

			intersectionPerms := intersection(cleanPermission, identityPermissions)
			if len(intersectionPerms) != len(cleanPermission) {
				fmt.Printf("# Missing required role: %s \n", role)
				valid = false
			}
		}
	}
	return valid
}

func intersection(a, b []string) []string {
	m := make(map[string]bool)
	for _, item := range a {
		m[item] = true
	}
	var res []string
	for _, item := range b {
		if _, ok := m[item]; ok {
			res = append(res, item)
		}
	}
	return res
}

func ValidateComponents(t testing.TB) bool {
	fmt.Println("")
	fmt.Println("# Validating local workspace dependencies.")
	valid := true

	components := []string{"terraform", "git", "gcloud"}
	for _, component := range components {
		_, err := exec.LookPath(component)
		if err == nil {
			fmt.Printf("# Local dependency '%s' is present.\n", component)
		} else {
			fmt.Printf("# Local dependency '%s' is missing!\n", component)
			valid = false
		}
	}
	return valid
}

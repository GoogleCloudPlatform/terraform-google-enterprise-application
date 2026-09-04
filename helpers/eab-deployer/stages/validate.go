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
	"os/exec"
	"strings"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/gcp"
	"github.com/mitchellh/go-testing-interface"
)

const (
	replaceME = "REPLACE_ME"
)

func ValidateBasicFields(t testing.TB, g GlobalTFVars) bool {
	fmt.Println("")
	fmt.Println("# Validating tfvar file.")
	valid := true

	if g.ProjectID == "" || strings.Contains(g.ProjectID, replaceME) {
		fmt.Println("# Replace value 'REPLACE_ME' for input 'project_id'")
		valid = false
	}
	if g.Region == "" || strings.Contains(g.Region, replaceME) {
		fmt.Println("# Replace value 'REPLACE_ME' for input 'region'")
		valid = false
	}
	if g.EABCodePath == "" || strings.Contains(g.EABCodePath, replaceME) {
		fmt.Println("# Replace value 'REPLACE_ME' for input 'eab_code_path'")
		valid = false
	}
	if g.CodeCheckoutPath == "" || strings.Contains(g.CodeCheckoutPath, replaceME) {
		fmt.Println("# Replace value 'REPLACE_ME' for input 'code_checkout_path'")
		valid = false
	}

	if g.CloudbuildV2RepositoryConfig == nil {
		fmt.Println("# Error: You must provide `cloudbuildv2_repository_config` in your tfvars file.")
		return false
	}

	if g.CloudbuildV2RepositoryConfig.RepoType == "GITHUBv2" &&
		(g.CloudbuildV2RepositoryConfig.GithubAppIDSecretID == nil || g.CloudbuildV2RepositoryConfig.GithubSecretID == nil) {
		fmt.Println("# You must provide `github_app_id_secret_id` and `github_secret_id` for cloudbuildv2_repository_config")
		valid = false
	}

	if g.CloudbuildV2RepositoryConfig.RepoType == "GITLABv2" &&
		(g.CloudbuildV2RepositoryConfig.GitlabAuthorizerCredentialSecretID == nil || g.CloudbuildV2RepositoryConfig.GitlabReadAuthorizerCredentialSecretID == nil || g.CloudbuildV2RepositoryConfig.GitlabWebhookSecretID == nil) {
		fmt.Println("# You must provide `gitlab_authorizer_credential_secret_id`, `gitlab_webhook_secret_id` and `gitlab_read_authorizer_credential_secret_id` for cloudbuildv2_repository_config")
		valid = false
	}

	return valid
}

func ValidatePermissions(t testing.TB, g GlobalTFVars) bool {
	fmt.Println("")
	fmt.Println("# Validating if identity has required roles on project.")
	valid := true

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

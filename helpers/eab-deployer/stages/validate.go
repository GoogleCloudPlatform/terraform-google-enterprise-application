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
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"regexp"
	"strings"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/gcp"
	"github.com/mitchellh/go-testing-interface"
	"github.com/tidwall/gjson"
)

const (
	replaceME     = "REPLACE_ME"
	exampleDotCom = "example.com"
)

var (
	requiredAPIs = []string{"accesscontextmanager.googleapis.com",
		"artifactregistry.googleapis.com",
		"anthos.googleapis.com",
		"anthosconfigmanagement.googleapis.com",
		"apikeys.googleapis.com",
		"binaryauthorization.googleapis.com",
		"certificatemanager.googleapis.com",
		"cloudbilling.googleapis.com",
		"cloudbuild.googleapis.com",
		"clouddeploy.googleapis.com",
		"cloudfunctions.googleapis.com",
		"cloudkms.googleapis.com",
		"cloudresourcemanager.googleapis.com",
		"cloudtrace.googleapis.com",
		"compute.googleapis.com",
		"container.googleapis.com",
		"containeranalysis.googleapis.com",
		"containerscanning.googleapis.com",
		"gkehub.googleapis.com",
		"iam.googleapis.com",
		"iap.googleapis.com",
		"mesh.googleapis.com",
		"monitoring.googleapis.com",
		"multiclusteringress.googleapis.com",
		"multiclusterservicediscovery.googleapis.com",
		"networkmanagement.googleapis.com",
		"orgpolicy.googleapis.com",
		"secretmanager.googleapis.com",
		"servicedirectory.googleapis.com",
		"servicemanagement.googleapis.com",
		"servicenetworking.googleapis.com",
		"serviceusage.googleapis.com",
		"sqladmin.googleapis.com",
		"storage.googleapis.com",
		"trafficdirector.googleapis.com",
	}
)

// ValidateDirectories checks if the required directories exist
func ValidateDirectories(g GlobalTFVars) error {
	_, err := os.Stat(g.EABCodePath)
	if os.IsNotExist(err) {
		return fmt.Errorf("Stopping execution, EABCodePath directory '%s' does not exits\n", g.EABCodePath)
	}
	_, err = os.Stat(g.CodeCheckoutPath)
	if os.IsNotExist(err) {
		return fmt.Errorf("Stopping execution, CodeCheckoutPath directory '%s' does not exits\n", g.CodeCheckoutPath)
	}
	return nil
}

// ValidateComponents checks if gcloud Beta Components and Terraform Tools are installed
func ValidateComponents(t testing.TB) error {
	gcpConf := gcp.NewGCP()
	components := []string{
		"beta",
		"terraform-tools",
	}
	missing := []string{}
	for _, c := range components {
		if !gcpConf.IsComponentInstalled(t, c) {
			missing = append(missing, fmt.Sprintf("'%s' not installed", c))
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("missing Google Cloud SDK component:%v", missing)
	}
	return nil
}

// ValidateBasicFields validates if the values for the required field were provided
func ValidateBasicFields(t testing.TB, g GlobalTFVars) {
	// gcpConf := gcp.NewGCP()
	fmt.Println("")
	fmt.Println("# Validating tfvar file.")

	g.CheckString(replaceME)

	for namespaces := range g.NamespaceIDs {
		if strings.Contains(namespaces, exampleDotCom) {
			fmt.Println("# Replace value 'example.com' for input 'namespace_ids'")
		}
	}

	if g.InfraCloudbuildV2RepositoryConfig.RepoType == "GITHUBv2" &&
		(g.InfraCloudbuildV2RepositoryConfig.GithubAppIDSecretID == nil || g.InfraCloudbuildV2RepositoryConfig.GithubSecretID == nil) {
		fmt.Println("# You must provide `github_app_id_secret_id` and `github_secret_id` for infra_cloudbuildv2_repository_config")
	}
	if g.AppServicesCloudbuildV2RepositoryConfig.RepoType == "GITHUBv2" &&
		(g.AppServicesCloudbuildV2RepositoryConfig.GithubAppIDSecretID == nil || g.AppServicesCloudbuildV2RepositoryConfig.GithubSecretID == nil) {
		fmt.Println("# You must provide `github_app_id_secret_id` and `github_secret_id` for app_services_cloudbuildv2_repository_config")
	}

	if g.InfraCloudbuildV2RepositoryConfig.RepoType == "GITLABv2" &&
		(g.InfraCloudbuildV2RepositoryConfig.GitlabAuthorizerCredentialSecretID == nil || g.InfraCloudbuildV2RepositoryConfig.GitlabReadAuthorizerCredentialSecretID == nil || g.InfraCloudbuildV2RepositoryConfig.GitlabWebhookSecretID == nil) {
		fmt.Println("# You must provide `gitlab_authorizer_credential_secret_id`, `gitlab_webhook_secret_id` and `gitlab_read_authorizer_credential_secret_id` for infra_cloudbuildv2_repository_config")
	}
	if g.AppServicesCloudbuildV2RepositoryConfig.RepoType == "GITLABv2" &&
		(g.AppServicesCloudbuildV2RepositoryConfig.GitlabAuthorizerCredentialSecretID == nil || g.AppServicesCloudbuildV2RepositoryConfig.GitlabReadAuthorizerCredentialSecretID == nil || g.AppServicesCloudbuildV2RepositoryConfig.GitlabWebhookSecretID == nil) {
		fmt.Println("# You must provide `gitlab_authorizer_credential_secret_id`, `gitlab_webhook_secret_id` and `gitlab_read_authorizer_credential_secret_id` for app_services_cloudbuildv2_repository_config")
	}
}

// ValidateRequiredAPIs validates if the project has the required APIs enabled.
func ValidateRequiredAPIs(t testing.TB, g GlobalTFVars) {
	fmt.Println("")
	fmt.Println("# Validating required APIs.")

	for _, requiredAPI := range requiredAPIs {
		if !gcp.NewGCP().IsApiEnabled(t, g.ProjectID, requiredAPI) {
			fmt.Printf("# Project `%s` is missing required API: `%s` \n", g.ProjectID, requiredAPI)
		}
	}
}

// ValidateRepositories checks if provided repositories are accessible.
func ValidateRepositories(t testing.TB, g GlobalTFVars) {
	if g.InfraCloudbuildV2RepositoryConfig.RepoType != "CSR" {
		fmt.Println("")
		fmt.Println("# Validating if repositories are accessible.")
		var pat string

		switch g.InfraCloudbuildV2RepositoryConfig.RepoType {
		case "GITHUBv2":
			pat = gcp.NewGCP().GetSecretValue(t, *g.InfraCloudbuildV2RepositoryConfig.GithubSecretID)
		case "GITLABv2":
			pat = gcp.NewGCP().GetSecretValue(t, *g.InfraCloudbuildV2RepositoryConfig.GitlabAuthorizerCredentialSecretID)
		}

		for _, repo := range g.InfraCloudbuildV2RepositoryConfig.Repositories {
			repoParts := strings.Split(repo.RepositoryURL, "/")

			client := &http.Client{}
			resp, err := client.Get(repo.RepositoryURL)
			if err != nil {
				fmt.Fprintf(os.Stderr, "# Error making request: %v\n", err)
			}
			defer resp.Body.Close()

			// Check for common success status codes (200-299).
			if !(resp.StatusCode >= 200 && resp.StatusCode < 300) {
				switch g.InfraCloudbuildV2RepositoryConfig.RepoType {
				case "GITHUBv2":
					repoURL := fmt.Sprintf("https://api.github.com/repos/%s/%s", repoParts[len(repoParts)-2], strings.ReplaceAll(repoParts[len(repoParts)-1], ".git", ""))
					req, err := http.NewRequest("GET", repoURL, nil)
					if err != nil {
						fmt.Fprintf(os.Stderr, "Error creating request: %v\n", err)
					}
					req.Header.Add("Authorization", "Bearer "+pat)
					resp, err := client.Do(req)
					if err != nil {
						fmt.Fprintf(os.Stderr, "Error making request: %v\n", err)
					}
					defer resp.Body.Close()

					if resp.StatusCode >= 200 && resp.StatusCode < 300 {
						fmt.Printf("# Repository is accessible and PRIVATE! %s\n", repo.RepositoryURL)
					} else {
						fmt.Printf("# Repository %s is NOT ACCESSIBLE! %d\n", repo.RepositoryURL, resp.StatusCode)
					}
				case "GITLABv2":
					repoURL := fmt.Sprintf("https://gitlab.com/api/v4/projects/%s/%s", repoParts[len(repoParts)-2], strings.ReplaceAll(repoParts[len(repoParts)-1], ".git", ""))
					req, err := http.NewRequest("HEAD", repoURL, nil)
					if err != nil {
						fmt.Fprintf(os.Stderr, "Error creating request: %v\n", err)
					}

					// GitLab uses the "PRIVATE-TOKEN" header for authentication with a PAT
					req.Header.Add("PRIVATE-TOKEN", pat)

					resp, err := client.Do(req)
					if err != nil {
						fmt.Fprintf(os.Stderr, "Error making request: %v\n", err)
					}
					defer resp.Body.Close()
					if resp.StatusCode >= 200 && resp.StatusCode < 300 {
						fmt.Printf("# Repository is accessible and PRIVATE! %s\n", repo.RepositoryURL)
					} else {
						fmt.Printf("# Repository %s is NOT ACCESSIBLE! %d\n", repo.RepositoryURL, resp.StatusCode)
					}
				}
			} else {
				fmt.Printf("# Repository is PUBLIC! %s\n", repo.RepositoryURL)
			}
		}
	}
}

// ValidateRepositories checks if provided repositories are accessible.
func ValidatePermissions(t testing.TB, g GlobalTFVars) {
	fmt.Println("")
	fmt.Println("# Validating if identity has required roles.")

	workerPoolInfo, err := extractInfoWithRegex(g.WorkerPoolID, `projects/(?P<project>[^/]+)/locations/(?P<location>[^/]+)/workerPools/(?P<workerPool>[^/]+)`)
	if err != nil {
		fmt.Printf("# error extracting info for private workerpool. %v \n", err)
	}

	projectRoles := map[string][]string{
		fmt.Sprintf("seedProject:%s", g.ProjectID): {
			"roles/cloudbuild.connectionAdmin",
			"roles/compute.networkAdmin",
			"roles/resourcemanager.projectIamAdmin",
		},
	}

	if g.InfraCloudbuildV2RepositoryConfig.SecretProjectID != nil && *g.InfraCloudbuildV2RepositoryConfig.SecretProjectID != "" {
		projectRoles[fmt.Sprintf("infraSecretProject:%s", *g.InfraCloudbuildV2RepositoryConfig.SecretProjectID)] = []string{
			"roles/secretmanager.admin",
		}
	}

	if g.AppServicesCloudbuildV2RepositoryConfig.SecretProjectID != nil && *g.AppServicesCloudbuildV2RepositoryConfig.SecretProjectID != "" {
		projectRoles[fmt.Sprintf("appSourceSecretProject:%s", *g.AppServicesCloudbuildV2RepositoryConfig.SecretProjectID)] = []string{
			"roles/secretmanager.admin",
		}
	}

	if g.AttestationKMSKey != nil {
		kmsInfo, err := extractInfoWithRegex(*g.AttestationKMSKey, `projects/(?P<project>[^/]+)/locations/(?P<location>[^/]+)/keyRings/(?P<keyRing>[^/]+)/cryptoKeys/(?P<cryptoKey>[^/]+)`)
		if err != nil {
			fmt.Printf("# error extracting info for ATTESTATION KMS PROJECT. %v \n", err)
		}

		if len(kmsInfo) > 0 {
			projectRoles[fmt.Sprintf("attestationKMSProject:%s", kmsInfo["project"])] = []string{
				"roles/resourcemanager.projectIamAdmin",
			}
		}
	}

	if g.BucketKMSKey != nil {
		kmsInfo, err := extractInfoWithRegex(*g.BucketKMSKey, `projects/(?P<project>[^/]+)/locations/(?P<location>[^/]+)/keyRings/(?P<keyRing>[^/]+)/cryptoKeys/(?P<cryptoKey>[^/]+)`)
		if err != nil {
			fmt.Printf("# error extracting info for BUCKET KMS PROJECT. %v \n", err)
		}

		if len(kmsInfo) > 0 {
			projectRoles[fmt.Sprintf("bucketKMSProject:%s", kmsInfo["project"])] = []string{
				"roles/resourcemanager.projectIamAdmin",
			}
		}
	}

	if len(workerPoolInfo) > 0 {
		projectRoles[fmt.Sprintf("cbPrivateWorkerPoolProject:%s", workerPoolInfo["project"])] = []string{
			"roles/cloudbuild.workerPoolUser",
			"roles/resourcemanager.projectIamAdmin",
		}
	}

	orgLevelRoles := []string{
		"roles/accesscontextmanager.policyAdmin",
	}

	folderLevelRoles := []string{
		"roles/resourcemanager.folderAdmin",
		"roles/resourcemanager.projectCreator",
		"roles/compute.networkAdmin",
		"roles/compute.xpnAdmin",
	}

	for indexProject, roles := range projectRoles {
		project := strings.Split(indexProject, ":")[1]
		for _, role := range roles {
			fmt.Printf("# Checking role %s at project %s. \n", role, project)

			rolePermissions, err := gcp.NewGCP().GetRolePermissions(t, role)
			if err != nil {
				fmt.Printf("# Error getting roles: %v\n", err)
				return
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
			identityPermissions, err := testIAMPermissions(t, cleanPermission, fmt.Sprintf("projects/%s", project))
			if err != nil {
				fmt.Printf("# Error testing roles: %v\n", err)
				return
			}

			if len(intersection(cleanPermission, identityPermissions)) != len(cleanPermission) {
				fmt.Printf("# Missing required role: %s \n", role)
			}
		}
	}

	for _, role := range orgLevelRoles {
		fmt.Printf("# Checking role %s at organization %s. \n", role, g.OrgID)

		rolePermissions, err := gcp.NewGCP().GetRolePermissions(t, role)
		if err != nil {
			fmt.Printf("# Error getting roles: %v\n", err)
			return
		}

		identityPermissions, err := testIAMPermissions(t, rolePermissions, fmt.Sprintf("organizations/%s", g.OrgID))
		if err != nil {
			fmt.Printf("# Error testing roles: %v\n", err)
			return
		}

		if len(intersection(rolePermissions, identityPermissions)) != len(rolePermissions) {
			fmt.Printf("# Missing required role: %s \n", role)
		}
	}

	for _, role := range folderLevelRoles {
		fmt.Printf("# Checking role %s at folder %s. \n", role, g.CommonFolderID)

		rolePermissions, err := gcp.NewGCP().GetRolePermissions(t, role)
		if err != nil {
			fmt.Printf("# Error getting roles: %v\n", err)
			return
		}
		cleanPermission := []string{}
		for _, permission := range rolePermissions {
			if permission != "resourcemanager.organizations.get" && permission != "networksecurity.firewallEndpoints.create" &&
				permission != "networksecurity.firewallEndpoints.delete" && permission != "networksecurity.firewallEndpoints.get" &&
				permission != "networksecurity.firewallEndpoints.list" && permission != "networksecurity.firewallEndpoints.update" &&
				permission != "networksecurity.firewallEndpoints.use" {
				cleanPermission = append(cleanPermission, permission)
			}
		}

		identityPermissions, err := testIAMPermissions(t, cleanPermission, g.CommonFolderID)
		if err != nil {
			fmt.Printf("# Error testing roles: %v\n", err)
			return
		}

		if len(intersection(cleanPermission, identityPermissions)) != len(cleanPermission) {
			fmt.Printf("# Missing required role: %s \n", role)
		}
	}
}

// testIAMPermissions checks a set of permissions against a parent (projects/PROJECT_ID or folders/FORLDER_ID of organizations/ORG_ID) using the cloudresourcemanager:testIamPermissions V3 API
func testIAMPermissions(t testing.TB, permissions []string, parent string) ([]string, error) {
	client := &http.Client{}
	identityPermissions := []string{}
	chunkSize := 100

	// avoid "The number of permissions (xxx) is greater than the maximum allowed (100).
	for i := 0; i < len(permissions); i += chunkSize {
		// Calculate the end index for the current chunk
		end := i + chunkSize
		if end > len(permissions) {
			end = len(permissions)
		}

		// Extract the current chunk
		chunk := permissions[i:end]

		requestBody := map[string][]string{"permissions": chunk}
		jsonBody, _ := json.Marshal(requestBody)
		req, err := http.NewRequest("POST", fmt.Sprintf("https://cloudresourcemanager.googleapis.com/v3/%s:testIamPermissions", parent), bytes.NewBuffer([]byte(jsonBody)))
		req.Header.Add("Authorization", "Bearer "+gcp.NewGCP().GetAuthToken(t))
		resp, err := client.Do(req)
		if err != nil {
			fmt.Printf("# Error making request: %v\n", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			bodyBytes, _ := io.ReadAll(resp.Body) // Read error body (ignore error to avoid shadowing)
			return nil, fmt.Errorf("# Error request failed with status code: %d, body: %s \n", resp.StatusCode, string(bodyBytes))
		} else {
			bodyBytes, err := io.ReadAll(resp.Body)
			if err != nil {
				return nil, fmt.Errorf("# Error failed to read response body: %w \n", err)
			}
			bodyJson := map[string][]string{}
			err = json.Unmarshal(bodyBytes, &bodyJson)
			if err != nil {
				return nil, fmt.Errorf("failed to unmarshal JSON: %w \n", err)
			}
			identityPermissions = append(identityPermissions, bodyJson["permissions"]...)
		}
	}
	return identityPermissions, nil
}

// ValidateDestroyFlags checks if the flags to allow the destruction of the infrastructure are enabled
func ValidateDestroyFlags(t testing.TB, g GlobalTFVars) {
	trueFlags := []string{}
	falseFlags := []string{}
	projectDeletion := false

	if !g.BucketForceDestroy {
		trueFlags = append(trueFlags, "buckets_force_destroy")
	}

	projectDeletion = g.DeletionProtection

	if len(trueFlags) > 0 || len(falseFlags) > 0 || projectDeletion {
		fmt.Println("# To use the feature to destroy the deployment created by this helper,")
		if len(trueFlags) > 0 {
			fmt.Println("# please set the following flags to 'true' in the tfvars file:")
			fmt.Printf("# %s\n", strings.Join(trueFlags, ", "))
		}
		if len(falseFlags) > 0 {
			fmt.Println("# please set the following flags to 'false' in the tfvars file:")
			fmt.Printf("# %s\n", strings.Join(falseFlags, ", "))
		}
		if projectDeletion {
			fmt.Println("# please set the project_deletion_policy input to 'DELETE' in the tfvars file")
		}
	}
}

func intersection(first, second []string) []string {
	out := []string{}
	bucket := map[string]bool{}

	for _, i := range first {
		for _, j := range second {
			if i == j && !bucket[i] {
				out = append(out, i)
				bucket[i] = true
			}
		}
	}

	return out
}

func extractInfoWithRegex(input, pattern string) (map[string]string, error) {
	re := regexp.MustCompile(pattern)
	match := re.FindStringSubmatch(input)

	if len(match) == 0 {
		return nil, fmt.Errorf("no match found.")
	}

	result := make(map[string]string)
	for i, name := range re.SubexpNames() {
		if i != 0 && name != "" {
			result[name] = match[i]
		}
	}

	return result, nil
}

func ipRangeSize(ipRange string, minimunSize int) bool {
	_, ipNet, err := net.ParseCIDR(ipRange)
	if err != nil {
		fmt.Println("Error parsing CIDR:", err)
		return false // Invalid CIDR format
	}

	ones, bits := ipNet.Mask.Size()
	prefixLength := ones

	return prefixLength <= (bits-minimunSize)+ones

}

func ValidateNetworkRequirementes(t testing.TB, g GlobalTFVars) {
	fmt.Println("# Checking Network Requirements.")
	for _, envs := range g.Envs {
		for _, subnet := range envs.SubnetsSelfLinks {
			fmt.Printf("# Checking subnet %s.", subnet)

			subnetInfo, err := extractInfoWithRegex(subnet, `projects/(?P<project>[^/]+)/regions/(?P<region>[^/]+)/subnetworks/(?P<subnet>[^/]+)`)
			if err != nil {
				fmt.Printf("# error extracting info for subnet. %v \n", err)
				return
			}

			res := gcp.NewGCP().Runf(t, "compute networks subnets describe %s --region=%s --project=%s", subnetInfo["subnet"], subnetInfo["region"], subnetInfo["project"])
			fmt.Println("# Checking Private Access.")
			if !res.Get("privateIpGoogleAccess").Bool() {
				fmt.Println("# Your subnet should have Private Access Enabled.")
			}

			fmt.Println("# Checking existance of secondary ranges.")
			if len(res.Get("secondaryIpRanges").Array()) < 2 {
				fmt.Println("# Your subnet should have at least 2 secondary ranges.")
			}

			fmt.Println("# Checking secondary ranges size.")
			for _, ipRange := range res.Get("secondaryIpRanges").Array() {
				if !ipRangeSize(ipRange.Get("ipCidrRange").String(), 18) {
					fmt.Printf("# Your secondary range %s should have at least a /18. Current: %s \n", ipRange.Get("rangeName").String(), ipRange.Get("ipCidrRange").String())
				}
			}
		}
	}

}

func ValidatePrivateWorkerPoolRequirementes(t testing.TB, g GlobalTFVars) {
	fmt.Println("# Checking Private Worker Pool requirements.")
	workerPoolInfo, err := extractInfoWithRegex(g.WorkerPoolID, `projects/(?P<project>[^/]+)/locations/(?P<location>[^/]+)/workerPools/(?P<workerPool>[^/]+)`)
	if err != nil {
		fmt.Println("Worker Pool ID is not in the correct format: `projects/PROJECT_ID/locations/LOCATION/workerPools/NAME`.")
	}

	res := gcp.NewGCP().Runf(t, "builds worker-pools describe %s --region=%s --project=%s", workerPoolInfo["workerPool"], workerPoolInfo["location"], workerPoolInfo["project"])

	if res.Get("privatePoolV1Config").Get("networkConfig").Get("egressOption").String() != "NO_PUBLIC_EGRESS" {
		fmt.Println("Your worker pool ALLOWS PUBLIC EGRESS! It should NOT.")
	}

	if res.Get("privatePoolV1Config").Get("networkConfig").Get("peeredNetwork").String() == "" {
		fmt.Println("Your worker pool is NOT private. Should have a peered Network.")
		return
	}
	if !ipRangeSize(fmt.Sprintf("0.0.0.0%s", res.Get("privatePoolV1Config").Get("networkConfig").Get("peeredNetworkIpRange").String()), 24) {
		fmt.Println("Your Peered IP range should be at least /24.")
	}

}

func ValidateVPCSCRequirements(t testing.TB, g GlobalTFVars) {
	fmt.Println("#Checking VPC-SC requirementes.")
	if g.ServicePerimeterName != nil {
		if g.AccessLevelName == nil {
			fmt.Println("You must provide the associated Access Level name to be used with Service Perimeter.")
			return
		}

		fmt.Println("#Checking if perimeter exists.")
		res := gcp.NewGCP().Runf(t, "access-context-manager perimeters describe %s ", g.ServicePerimeterName)
		found := false
		fieldToCheck := "status"
		if *g.ServicePerimeterMode == "DRY_RUN" {
			fieldToCheck = "spec"
		}
		res.Get(fieldToCheck).Get("accessLevels").ForEach(func(k, v gjson.Result) bool {
			if v.String() == *g.AccessLevelName {
				found = true
				return false
			}
			return true
		})
		if !found {
			fmt.Println("#The access level provided does not match if the access levels associated with service perimeter.")
		}
	} else {
		fmt.Println("#No Service Perimeter provided.")
	}
}

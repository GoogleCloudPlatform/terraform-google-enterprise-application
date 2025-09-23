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
	"net/http"
	"os"
	"regexp"
	"strings"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/gcp"
	"github.com/mitchellh/go-testing-interface"
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

	test, _ := regexp.MatchString(g.KMSProjectID, g.BucketKMSKey)
	if !test {
		fmt.Println("# You `kms_project_id` must be the same in your `bucket_kms_key`")
	}

	test, _ = regexp.MatchString(g.AttestationKMSProject, g.AttestationKMSKey)
	if !test {
		fmt.Println("# You `attestation_kms_project` must be the same in your `attestation_kms_key`")
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
	fmt.Println("")
	fmt.Println("# Validating if repositories are accessible.")
	var pat string

	switch g.InfraCloudbuildV2RepositoryConfig.RepoType {
	case "GITHUBv2":
		pat = gcp.NewGCP().GetSecretValue(t, g.InfraCloudbuildV2RepositoryConfig.GithubSecretID)
	case "GITLABv2":
		pat = gcp.NewGCP().GetSecretValue(t, g.InfraCloudbuildV2RepositoryConfig.GitlabAuthorizerCredentialSecretID)
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

// ValidateDestroyFlags checks if the flags to allow the destruction of the infrastructure are enabled
func ValidateDestroyFlags(t testing.TB, g GlobalTFVars) {
	trueFlags := []string{}
	falseFlags := []string{}
	projectDeletion := false

	if !g.BucketForceDestroy {
		trueFlags = append(trueFlags, "buckets_force_destroy")
	}
	if !g.BucketsForceDestroy {
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

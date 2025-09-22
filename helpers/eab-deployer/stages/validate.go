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
	"regexp"
	"strings"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/gcp"
	"github.com/mitchellh/go-testing-interface"
)

const (
	replaceME     = "REPLACE_ME"
	exampleDotCom = "example.com"
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

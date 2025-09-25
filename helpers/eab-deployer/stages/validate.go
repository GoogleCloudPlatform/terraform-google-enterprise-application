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
	"strings"

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

// ValidateBasicFields validates if the values for the required field were provided
func ValidateBasicFields(t testing.TB, g GlobalTFVars) {
	// gcpConf := gcp.NewGCP()
	fmt.Println("")
	fmt.Println("# Validating tfvar file.")

	g.CheckString(replaceME)

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

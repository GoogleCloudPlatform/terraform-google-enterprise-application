// Copyright 2024 Google LLC
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

package testutils

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/shell"
	"github.com/tidwall/gjson"
)

// fileExists check if a give file exists
func FileExists(filePath string) (bool, error) {
	_, err := os.Stat(filePath)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}

// filter select only values who match the condition for the field
func Filter(field string, value string, iamList []gjson.Result) []gjson.Result {
	var filtered []gjson.Result

	for _, iam := range iamList {
		if strings.Contains(iam.Get(field).String(), value) {
			filtered = append(filtered, iam)
		}
	}
	return filtered
}

// verify if gjson array of string contains another string
func Contains(slice []gjson.Result, item string) bool {
	for _, v := range slice {
		if v.String() == item {
			return true
		}
	}
	return false
}

// Will walk directories searching for terraform.tfvars and replace the pattern with the replacement
func ReplacePatternInTfVars(pattern string, replacement string, root string) error {
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, fnErr error) error {
		if fnErr != nil {
			return fnErr
		}
		if !d.IsDir() && d.Name() == "terraform.tfvars" {
			return replaceInFile(path, pattern, replacement)
		}
		return nil
	})

	return err
}

// Will walk directories searching for fileName and replace the pattern with the replacement
func ReplacePatternInFile(pattern string, replacement string, root string, fileName string) error {
	err := filepath.WalkDir(root, func(path string, d fs.DirEntry, fnErr error) error {
		if fnErr != nil {
			return fnErr
		}
		if !d.IsDir() && d.Name() == fileName {
			return replaceInFile(path, pattern, replacement)
		}
		return nil
	})

	return err
}

// Will replace oldPattern in filePath with newPattern
func replaceInFile(filePath, oldPattern, newPattern string) error {
	fileInfo, err := os.Lstat(filePath)
	if err != nil {
		return err
	}

	if fileInfo.Mode()&os.ModeSymlink != 0 {
		fmt.Printf("%s is a symlink, will skip the pattern replacement.", filePath)
		return nil
	} else {
		content, err := os.ReadFile(filePath)
		if err != nil {
			return err
		}

		newContent := strings.ReplaceAll(string(content), oldPattern, newPattern)

		err = os.WriteFile(filePath, []byte(newContent), 0644)
		if err != nil {
			return err
		}

		fmt.Printf("Updated file: %s\n", filePath)

		return nil
	}
}

func GetSecretFromSecretManager(t *testing.T, secretName string, secretProject string) (string, error) {
	t.Log("Retrieving secret from secret manager.")
	cmd := fmt.Sprintf("secrets versions access latest --project=%s --secret=%s", secretProject, secretName)
	args := strings.Fields(cmd)
	gcloudCmd := shell.Command{
		Command: "gcloud",
		Args:    args,
		Logger:  logger.Discard,
	}
	return shell.RunCommandAndGetStdOutE(t, gcloudCmd)
}

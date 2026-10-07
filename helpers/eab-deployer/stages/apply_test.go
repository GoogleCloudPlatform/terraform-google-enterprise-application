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
	"os"
	"path/filepath"
	"testing"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/steps"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/stretchr/testify/assert"
)

func TestGetStandalonePaths(t *testing.T) {
	tempDir := t.TempDir()
	eabDir := filepath.Join(tempDir, "eab")
	checkoutDir := filepath.Join(tempDir, "checkout")

	// Create standalone example structure
	standaloneDir := filepath.Join(eabDir, "examples", "default-example", "standalone-single-project")
	err := os.MkdirAll(standaloneDir, 0755)
	assert.NoError(t, err)

	cymbalBankDir := filepath.Join(eabDir, "examples", "cymbal-bank", "standalone-single-project")
	err = os.MkdirAll(cymbalBankDir, 0755)
	assert.NoError(t, err)

	t.Run("resolves exact example name", func(t *testing.T) {
		src, dest, err := getStandalonePaths(eabDir, checkoutDir, "default-example")
		assert.NoError(t, err)
		assert.Equal(t, standaloneDir, src)
		assert.Equal(t, filepath.Join(checkoutDir, "examples", "default-example", "standalone-single-project"), dest)
	})

	t.Run("resolves underscore to hyphen normalization", func(t *testing.T) {
		src, dest, err := getStandalonePaths(eabDir, checkoutDir, "cymbal_bank")
		assert.NoError(t, err)
		assert.Equal(t, cymbalBankDir, src)
		assert.Equal(t, filepath.Join(checkoutDir, "examples", "cymbal-bank", "standalone-single-project"), dest)
	})

	t.Run("returns error for non-existent example", func(t *testing.T) {
		_, _, err := getStandalonePaths(eabDir, checkoutDir, "non-existent-blueprint")
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "could not find example directory")
	})
}

func TestDeployAppSourceStage_Validation(t *testing.T) {
	tempDir := t.TempDir()
	s, err := steps.LoadSteps(filepath.Join(tempDir, "steps.json"))
	assert.NoError(t, err)

	conf := CommonConf{
		EABPath:      tempDir,
		CheckoutPath: tempDir,
		Logger:       logger.Discard,
		ExampleName:  "default-example",
	}

	t.Run("fails when cloudbuild config is nil", func(t *testing.T) {
		tfvars := GlobalTFVars{
			CloudbuildV2RepositoryConfig: nil,
		}
		err := DeployAppSourceStage(t, s, tfvars, conf)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "cloudbuildv2_repository_config is required")
	})

	t.Run("fails when standalone path does not exist", func(t *testing.T) {
		tfvars := GlobalTFVars{
			CloudbuildV2RepositoryConfig: &CloudbuildV2RepositoryConfig{
				Repositories: map[string]Repository{
					"test": {RepositoryName: "test-repo"},
				},
			},
		}
		err := DeployAppSourceStage(t, s, tfvars, conf)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "could not find example directory")
	})

	t.Run("succeeds without action when repositories map is empty", func(t *testing.T) {
		standaloneDir := filepath.Join(tempDir, "examples", "default-example", "standalone-single-project")
		err := os.MkdirAll(standaloneDir, 0755)
		assert.NoError(t, err)

		tfvars := GlobalTFVars{
			CloudbuildV2RepositoryConfig: &CloudbuildV2RepositoryConfig{
				Repositories: map[string]Repository{},
			},
		}
		err = DeployAppSourceStage(t, s, tfvars, conf)
		assert.NoError(t, err)
	})
}

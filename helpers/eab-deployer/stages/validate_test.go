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

	"github.com/stretchr/testify/assert"
)

func TestValidateBasicFields(t *testing.T) {
	tempDir := t.TempDir()
	eabDir := filepath.Join(tempDir, "eab")
	_ = os.MkdirAll(eabDir, 0755)

	validConfig := GlobalTFVars{
		ProjectID:        "my-test-project",
		Region:           "us-central1",
		EABCodePath:      eabDir,
		CodeCheckoutPath: tempDir,
		CloudbuildV2RepositoryConfig: &CloudbuildV2RepositoryConfig{
			RepoType: "CSR",
			Repositories: map[string]Repository{
				"hello-world": {
					RepositoryName: "hello-world-admin",
					RepositoryURL:  "",
				},
			},
		},
	}

	t.Run("valid configuration passes", func(t *testing.T) {
		assert.True(t, ValidateBasicFields(t, validConfig))
	})

	t.Run("missing project_id fails", func(t *testing.T) {
		cfg := validConfig
		cfg.ProjectID = ""
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("placeholder project_id fails", func(t *testing.T) {
		cfg := validConfig
		cfg.ProjectID = "YOUR_EXISTING_PROJECT_ID"
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("placeholder REPLACE_ME fails", func(t *testing.T) {
		cfg := validConfig
		cfg.ProjectID = "REPLACE_ME_PROJECT"
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("missing region fails", func(t *testing.T) {
		cfg := validConfig
		cfg.Region = ""
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("non-existent eab_code_path fails", func(t *testing.T) {
		cfg := validConfig
		cfg.EABCodePath = "/non/existent/path/for/sure"
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("nil cloudbuild config fails", func(t *testing.T) {
		cfg := validConfig
		cfg.CloudbuildV2RepositoryConfig = nil
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("invalid repo_type fails", func(t *testing.T) {
		cfg := validConfig
		cfg.CloudbuildV2RepositoryConfig = &CloudbuildV2RepositoryConfig{
			RepoType: "INVALID_TYPE",
			Repositories: map[string]Repository{
				"test": {RepositoryName: "test"},
			},
		}
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("github without secrets fails", func(t *testing.T) {
		cfg := validConfig
		cfg.CloudbuildV2RepositoryConfig = &CloudbuildV2RepositoryConfig{
			RepoType: "GITHUBv2",
			Repositories: map[string]Repository{
				"test": {RepositoryName: "test", RepositoryURL: "https://github.com/org/repo"},
			},
		}
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("gitlab without authorizer secrets fails", func(t *testing.T) {
		cfg := validConfig
		cfg.CloudbuildV2RepositoryConfig = &CloudbuildV2RepositoryConfig{
			RepoType: "GITLABv2",
			Repositories: map[string]Repository{
				"test": {RepositoryName: "test", RepositoryURL: "https://gitlab.com/org/repo"},
			},
		}
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("empty repositories map fails", func(t *testing.T) {
		cfg := validConfig
		cfg.CloudbuildV2RepositoryConfig = &CloudbuildV2RepositoryConfig{
			RepoType:     "CSR",
			Repositories: map[string]Repository{},
		}
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("service perimeter without access level fails", func(t *testing.T) {
		cfg := validConfig
		sp := "accessPolicies/123/servicePerimeters/my_sp"
		cfg.ServicePerimeterName = &sp
		cfg.AccessLevelName = nil
		assert.False(t, ValidateBasicFields(t, cfg))
	})

	t.Run("placeholder optional input fails", func(t *testing.T) {
		cfg := validConfig
		wp := "projects/YOUR_EXISTING_PROJECT_ID/locations/us-central1/workerPools/YOUR_POOL_NAME"
		cfg.WorkerPoolID = &wp
		assert.False(t, ValidateBasicFields(t, cfg))
	})
}

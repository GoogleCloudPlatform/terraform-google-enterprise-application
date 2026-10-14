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

func TestReadGlobalTFVars(t *testing.T) {
	tempDir := t.TempDir()

	t.Run("empty filename returns error", func(t *testing.T) {
		_, err := ReadGlobalTFVars("")
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "tfvars file is required")
	})

	t.Run("non-existent file returns error", func(t *testing.T) {
		_, err := ReadGlobalTFVars(filepath.Join(tempDir, "missing.tfvars"))
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "does not exist")
	})

	t.Run("invalid HCL content returns error", func(t *testing.T) {
		invalidFile := filepath.Join(tempDir, "invalid.tfvars")
		err := os.WriteFile(invalidFile, []byte("invalid = {{{{"), 0644)
		assert.NoError(t, err)

		_, err = ReadGlobalTFVars(invalidFile)
		assert.Error(t, err)
		assert.Contains(t, err.Error(), "failed to load tfvars file")
	})

	t.Run("valid HCL tfvars parses correctly", func(t *testing.T) {
		validFile := filepath.Join(tempDir, "valid.tfvars")
		hclContent := `
project_id         = "my-project-123"
region             = "us-central1"
eab_code_path      = "/path/to/eab"
code_checkout_path = "/path/to/checkout"
attestation_kms_key = "projects/my-project/locations/us-central1/keyRings/my-kr/cryptoKeys/my-key"

teams = {
  "cb-frontend" = "frontend@example.com"
}

cloudbuildv2_repository_config = {
  repo_type = "CSR"
  repositories = {
    "eab-cymbal-bank-frontend" = {
      repository_name = "eab-cymbal-bank-frontend"
      repository_url  = ""
    }
  }
  github_secret_id                            = null
  github_app_id_secret_id                     = null
  gitlab_read_authorizer_credential_secret_id = null
  gitlab_authorizer_credential_secret_id      = null
  gitlab_webhook_secret_id                    = null
  gitlab_enterprise_host_uri                  = null
  gitlab_enterprise_service_directory         = null
  gitlab_enterprise_ca_certificate            = null
  secret_project_id                           = null
}
`
		err := os.WriteFile(validFile, []byte(hclContent), 0644)
		assert.NoError(t, err)

		tfvars, err := ReadGlobalTFVars(validFile)
		assert.NoError(t, err)
		assert.Equal(t, "my-project-123", tfvars.ProjectID)
		assert.Equal(t, "us-central1", tfvars.Region)
		assert.Equal(t, "/path/to/eab", tfvars.EABCodePath)
		assert.Equal(t, "/path/to/checkout", tfvars.CodeCheckoutPath)
		assert.NotNil(t, tfvars.AttestationKMSKey)
		assert.Equal(t, "projects/my-project/locations/us-central1/keyRings/my-kr/cryptoKeys/my-key", *tfvars.AttestationKMSKey)
		assert.Equal(t, "frontend@example.com", tfvars.Teams["cb-frontend"])
		assert.NotNil(t, tfvars.CloudbuildV2RepositoryConfig)
		assert.Equal(t, "CSR", tfvars.CloudbuildV2RepositoryConfig.RepoType)
		assert.Contains(t, tfvars.CloudbuildV2RepositoryConfig.Repositories, "eab-cymbal-bank-frontend")
	})
}

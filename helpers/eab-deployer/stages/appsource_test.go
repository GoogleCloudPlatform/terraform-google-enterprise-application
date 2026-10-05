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
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/git"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/stretchr/testify/assert"
)

func createMockGitRepoWithTag(t *testing.T, repoName, tag string, files map[string]string) string {
	dir := t.TempDir()
	repoPath := filepath.Join(dir, repoName)
	err := os.MkdirAll(repoPath, 0755)
	assert.NoError(t, err)

	conf := git.NewCmdConfig(t, git.WithDir(repoPath))
	conf.Init()

	cmdEmail := exec.Command("git", "config", "user.email", "test@example.com")
	cmdEmail.Dir = repoPath
	_ = cmdEmail.Run()
	cmdName := exec.Command("git", "config", "user.name", "Test User")
	cmdName.Dir = repoPath
	_ = cmdName.Run()

	for relPath, content := range files {
		fullPath := filepath.Join(repoPath, relPath)
		_ = os.MkdirAll(filepath.Dir(fullPath), 0755)
		_ = os.WriteFile(fullPath, []byte(content), 0644)
	}

	conf.AddAll()
	conf.CommitWithMsg("Initial commit", nil)

	if tag != "" {
		cmdTag := exec.Command("git", "tag", tag)
		cmdTag.Dir = repoPath
		err = cmdTag.Run()
		assert.NoError(t, err)
	}

	return repoPath
}

func TestPrepareSelfContained(t *testing.T) {
	tempDir := t.TempDir()
	eabDir := filepath.Join(tempDir, "eab")
	checkoutDir := filepath.Join(tempDir, "checkout")
	targetDir := filepath.Join(tempDir, "target")

	appSrcDir := filepath.Join(eabDir, "examples", "default-example", "6-appsource", "default-example", "hello-world")
	err := os.MkdirAll(appSrcDir, 0755)
	assert.NoError(t, err)
	err = os.WriteFile(filepath.Join(appSrcDir, "main.go"), []byte("package main\n"), 0644)
	assert.NoError(t, err)

	conf := CommonConf{
		EABPath:      eabDir,
		CheckoutPath: checkoutDir,
		Logger:       logger.Discard,
		ExampleName:  "default-example",
	}

	preparer := GetAppSourcePreparer("default-example")
	err = preparer.Prepare(t, conf, "", "", "hello-world", targetDir)
	assert.NoError(t, err)
	assert.FileExists(t, filepath.Join(targetDir, "main.go"))
}

func TestPrepareCymbalShop(t *testing.T) {
	tempDir := t.TempDir()
	eabDir := filepath.Join(tempDir, "eab")
	checkoutDir := filepath.Join(tempDir, "checkout")
	targetDir := filepath.Join(tempDir, "target")
	testAppVersion := "v0.10.5"

	// Create mock upstream repository
	mockUpstream := createMockGitRepoWithTag(t, "microservices-demo", testAppVersion, map[string]string{
		"README.md":                          "# Microservices Demo\n",
		"src/frontend/main.go":               "package main\n",
		"src/cartservice/cart.go":            "package main\n",
		"kubernetes-manifests/original.yaml": "original\n",
	})

	// Pre-populate cache with the mock upstream to avoid real network git clone
	cacheDir := filepath.Join(checkoutDir, ".cache", "microservices-demo-"+testAppVersion)
	_ = os.MkdirAll(filepath.Dir(cacheDir), 0755)
	cmdClone := exec.Command("git", "clone", "--depth", "1", "--branch", testAppVersion, mockUpstream, cacheDir)
	err := cmdClone.Run()
	assert.NoError(t, err)

	// Create mock 6-appsource overlays
	shopAppSource := filepath.Join(eabDir, "examples", "cymbal-shop", "6-appsource", "cymbal-shop")
	_ = os.MkdirAll(shopAppSource, 0755)
	_ = os.WriteFile(filepath.Join(shopAppSource, "cloudbuild.yaml"), []byte("custom-cloudbuild"), 0644)
	_ = os.WriteFile(filepath.Join(shopAppSource, "skaffold.yaml"), []byte("custom-skaffold"), 0644)

	conf := CommonConf{
		EABPath:      eabDir,
		CheckoutPath: checkoutDir,
		Logger:       logger.Discard,
		ExampleName:  "cymbal-shop",
	}

	preparer := GetAppSourcePreparer("cymbal-shop")
	err = preparer.Prepare(t, conf, mockUpstream, testAppVersion, "eab-cymbal-shop-cymbalshop", targetDir)
	assert.NoError(t, err)

	// Verify base files and overlays exist in target
	assert.FileExists(t, filepath.Join(targetDir, "README.md"))
	assert.FileExists(t, filepath.Join(targetDir, "src", "frontend", "main.go"))
	assert.FileExists(t, filepath.Join(targetDir, "cloudbuild.yaml"))
	assert.FileExists(t, filepath.Join(targetDir, "skaffold.yaml"))

	content, err := os.ReadFile(filepath.Join(targetDir, "cloudbuild.yaml"))
	assert.NoError(t, err)
	assert.Equal(t, "custom-cloudbuild", string(content))
}

func TestPrepareCymbalBank(t *testing.T) {
	tempDir := t.TempDir()
	eabDir := filepath.Join(tempDir, "eab")
	checkoutDir := filepath.Join(tempDir, "checkout")
	targetDir := filepath.Join(tempDir, "target")
	testAppVersion := "v0.6.9"

	// Create mock upstream repository
	mockUpstream := createMockGitRepoWithTag(t, "bank-of-anthos", testAppVersion, map[string]string{
		"README.md":                           "# Bank of Anthos\n",
		"src/components/old.yaml":             "old-component\n",
		"src/frontend/Main.java":              "public class Main {}\n",
		"src/accounts/contacts/Contacts.java": "public class Contacts {}\n",
		"src/ledger/balancereader/Bal.java":   "public class Bal {}\n",
	})

	// Pre-populate cache with the mock upstream to avoid real network git clone
	cacheDir := filepath.Join(checkoutDir, ".cache", "bank-of-anthos-"+testAppVersion)
	_ = os.MkdirAll(filepath.Dir(cacheDir), 0755)
	cmdClone := exec.Command("git", "clone", "--depth", "1", "--branch", testAppVersion, mockUpstream, cacheDir)
	err := cmdClone.Run()
	assert.NoError(t, err)

	// Create mock 6-appsource structure for cymbal-bank
	bankAppSource := filepath.Join(eabDir, "examples", "cymbal-bank", "6-appsource", "cymbal-bank")
	_ = os.MkdirAll(filepath.Join(bankAppSource, "components"), 0755)
	_ = os.WriteFile(filepath.Join(bankAppSource, "components", "new_component.yaml"), []byte("new-component"), 0644)

	_ = os.MkdirAll(filepath.Join(bankAppSource, "ledger-db", "k8s", "overlays"), 0755)
	_ = os.WriteFile(filepath.Join(bankAppSource, "ledger-db", "k8s", "overlays", "ledger-db.yaml"), []byte("ledger-db-overlay"), 0644)

	_ = os.MkdirAll(filepath.Join(bankAppSource, "accounts-db", "k8s", "overlays"), 0755)
	_ = os.WriteFile(filepath.Join(bankAppSource, "accounts-db", "k8s", "overlays", "accounts-db.yaml"), []byte("accounts-db-overlay"), 0644)

	_ = os.MkdirAll(filepath.Join(bankAppSource, "frontend", "k8s"), 0755)
	_ = os.WriteFile(filepath.Join(bankAppSource, "frontend", "skaffold.yaml"), []byte("frontend-skaffold"), 0644)
	_ = os.WriteFile(filepath.Join(bankAppSource, "frontend", "k8s", "ingress.yaml"), []byte("ingress"), 0644)

	_ = os.MkdirAll(filepath.Join(bankAppSource, "cloudbuild-files", "frontend"), 0755)
	_ = os.WriteFile(filepath.Join(bankAppSource, "cloudbuild-files", "frontend", "cloudbuild.yaml"), []byte("frontend-cloudbuild"), 0644)

	_ = os.MkdirAll(filepath.Join(bankAppSource, "cloudbuild-files", "ledger"), 0755)
	_ = os.WriteFile(filepath.Join(bankAppSource, "cloudbuild-files", "ledger", "cloudbuild.yaml"), []byte("ledger-cloudbuild"), 0644)

	_ = os.MkdirAll(filepath.Join(bankAppSource, "cloudbuild-files", "accounts"), 0755)
	_ = os.WriteFile(filepath.Join(bankAppSource, "cloudbuild-files", "accounts", "cloudbuild.yaml"), []byte("accounts-cloudbuild"), 0644)

	conf := CommonConf{
		EABPath:      eabDir,
		CheckoutPath: checkoutDir,
		Logger:       logger.Discard,
		ExampleName:  "cymbal-bank",
	}

	preparer := GetAppSourcePreparer("cymbal-bank")
	err = preparer.Prepare(t, conf, mockUpstream, testAppVersion, "eab-cymbal-bank-frontend", targetDir)
	assert.NoError(t, err)

	// Verify base files and overlays exist in target
	assert.FileExists(t, filepath.Join(targetDir, "README.md"))
	assert.FileExists(t, filepath.Join(targetDir, "src", "frontend", "Main.java"))
	assert.FileExists(t, filepath.Join(targetDir, "src", "components", "new_component.yaml"))
	assert.NoFileExists(t, filepath.Join(targetDir, "src", "components", "old.yaml"))
	assert.FileExists(t, filepath.Join(targetDir, "src", "ledger", "ledger-db", "k8s", "overlays", "ledger-db.yaml"))
	assert.FileExists(t, filepath.Join(targetDir, "src", "accounts", "accounts-db", "k8s", "overlays", "accounts-db.yaml"))
	assert.FileExists(t, filepath.Join(targetDir, "src", "frontend", "skaffold.yaml"))
	assert.FileExists(t, filepath.Join(targetDir, "src", "frontend", "k8s", "ingress.yaml"))
	assert.FileExists(t, filepath.Join(targetDir, "src", "frontend", "cloudbuild.yaml"))
	assert.FileExists(t, filepath.Join(targetDir, "src", "ledger", "cloudbuild.yaml"))
	assert.FileExists(t, filepath.Join(targetDir, "src", "accounts", "cloudbuild.yaml"))
}

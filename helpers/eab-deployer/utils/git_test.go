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

package utils

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/git"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/stretchr/testify/assert"
)

func createLocalRepo(t *testing.T, repo string) string {
	dir := t.TempDir()
	local := filepath.Join(dir, repo)
	err := os.MkdirAll(local, 0755)
	assert.NoError(t, err)
	conf := git.NewCmdConfig(t, git.WithDir(local))
	conf.Init()
	f := filepath.Join(local, "README.md")
	err = os.WriteFile(f, []byte("# Testing\n"), 0644)
	assert.NoError(t, err)
	conf.AddAll()
	conf.CommitWithMsg("Initial commit", nil)
	return local
}

func TestGitCSR(t *testing.T) {
	remote := "origin"
	repo := createLocalRepo(t, "my-csr-git-repo")
	originPath := filepath.Join(t.TempDir(), "my-csr-git-repo-origin")
	err := CopyDirectory(repo, originPath)
	assert.NoError(t, err)

	// Test GitClone with CSR
	localCSR := GitClone(t, "CSR", "my-csr-git-repo", repo, repo, "", logger.Discard)
	assert.NotNil(t, localCSR)
	err = localCSR.AddRemote(remote, originPath)
	assert.NoError(t, err)

	err = localCSR.CheckoutBranch("unit-test")
	assert.NoError(t, err)

	localBranch, err := localCSR.GetCurrentBranch()
	assert.Equal(t, localBranch, "unit-test", "current branch should be 'unit-test'")
	assert.NoError(t, err)

	err = os.WriteFile(filepath.Join(repo, "go.mod"), []byte("module example.com/test\n"), 0644)
	assert.NoError(t, err)

	err = localCSR.CommitFiles("add go mod file")
	assert.NoError(t, err)

	err = localCSR.PushBranch("unit-test", remote)
	assert.NoError(t, err)

	hasUpstream, err := localCSR.HasUpstream("unit-test", remote)
	assert.NoError(t, err)
	assert.True(t, hasUpstream, "branch 'unit-test' should have a remote")

	origin := cloneCSR(t, "my-csr-git-repo", originPath, "", logger.Discard)
	files, err := FindFiles(originPath, "go.mod")
	assert.NoError(t, err)
	assert.Len(t, files, 0, "'go.mod' file should not exist on main branch")

	err = origin.CheckoutBranch("unit-test")
	assert.NoError(t, err)
	files, err = FindFiles(originPath, "go.mod")
	assert.NoError(t, err)
	assert.Len(t, files, 1, "'go.mod' file should exist on 'unit-test' branch")

	// Test CheckoutBranch when the branch already exists
	err = localCSR.CheckoutBranch("unit-test")
	assert.NoError(t, err)

	// Test CommitFiles with no changes
	err = localCSR.CommitFiles("no changes")
	assert.NoError(t, err)

	// Test GetCommitSha
	_, err = localCSR.GetCommitSha()
	assert.NoError(t, err)
}

func TestGitClone_NonCSR(t *testing.T) {
	remote := "origin"
	repoURL := "https://github.com/google/blueprint-test.git"
	repo := createLocalRepo(t, "my-git-repo")
	originPath := filepath.Join(t.TempDir(), "my-git-repo-origin")
	err := CopyDirectory(repo, originPath)
	assert.NoError(t, err)

	local := GitClone(t, "GITHUB", "blueprint-test", repoURL, originPath, "", logger.Discard)
	assert.NotNil(t, local)

	// Check if the directory is created
	if _, err := os.Stat(originPath); errors.Is(err, os.ErrNotExist) {
		t.Fatalf("Directory not created: %s", originPath)
	}

	assert.NotNil(t, local)
	err = local.AddRemote(remote, originPath)
	assert.NoError(t, err)

	err = local.CheckoutBranch("unit-test")
	assert.NoError(t, err)

	localBranch, err := local.GetCurrentBranch()
	assert.Equal(t, localBranch, "unit-test", "current branch should be 'unit-test'")
	assert.NoError(t, err)

	err = os.WriteFile(filepath.Join(repo, "go.mod"), []byte("module example.com/test\n"), 0644)
	assert.NoError(t, err)

	err = local.CommitFiles("add go mod file")
	assert.NoError(t, err)

	err = local.PushBranch("unit-test", remote)
	assert.NoError(t, err)

	hasUpstream, err := local.HasUpstream("unit-test", remote)
	assert.NoError(t, err)
	assert.True(t, hasUpstream, "branch 'unit-test' should have a remote")
}

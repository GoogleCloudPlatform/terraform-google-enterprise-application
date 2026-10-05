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
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/utils"
	"github.com/mitchellh/go-testing-interface"
)

// AppSourcePreparer defines the contract for assembling and preparing application source code for target repositories.
type AppSourcePreparer interface {
	Prepare(t testing.TB, c CommonConf, appSourceRepoURL, appVersion, serviceKey, targetGitPath string) error
}

// GetAppSourcePreparer returns the appropriate AppSourcePreparer strategy for the given example.
func GetAppSourcePreparer(exampleName string) AppSourcePreparer {
	normExample := strings.ReplaceAll(exampleName, "_", "-")
	switch normExample {
	case "cymbal-shop":
		return &CymbalShopPreparer{}
	case "cymbal-bank":
		return &CymbalBankPreparer{}
	default:
		return &SelfContainedPreparer{ExampleName: exampleName}
	}
}

// SelfContainedPreparer handles examples where source code lives directly inside 6-appsource.
type SelfContainedPreparer struct {
	ExampleName string
}

func (p *SelfContainedPreparer) Prepare(t testing.TB, c CommonConf, appSourceRepoURL, appVersion, serviceKey, targetGitPath string) error {
	appSrcDir := getAppSourcePath(c, p.ExampleName, serviceKey)
	if appSrcDir == "" {
		return fmt.Errorf("could not find app source path for example %s, service %s", p.ExampleName, serviceKey)
	}
	return utils.CopyDirectory(appSrcDir, targetGitPath)
}

func getAppSourcePath(c CommonConf, exampleName, serviceName string) string {
	pathsToCheck := []string{
		filepath.Join(c.EABPath, "examples", exampleName, "6-appsource", exampleName, serviceName),
		filepath.Join(c.EABPath, "examples", exampleName, "6-appsource", serviceName),
		filepath.Join(c.EABPath, "examples", exampleName, "6-appsource", exampleName),
		filepath.Join(c.EABPath, "examples", exampleName, "6-appsource"),
	}
	for _, path := range pathsToCheck {
		if fi, err := os.Stat(path); err == nil && fi.IsDir() {
			return path
		}
	}
	return ""
}

// CymbalShopPreparer handles cloning microservices-demo and applying local 6-appsource overlays.
type CymbalShopPreparer struct{}

func (p *CymbalShopPreparer) Prepare(t testing.TB, c CommonConf, appSourceRepoURL, appVersion, serviceKey, targetGitPath string) error {
	if appSourceRepoURL == "" {
		return fmt.Errorf("app_source_repo_url is required for cymbal-shop")
	}
	if appVersion == "" {
		return fmt.Errorf("app_version is required for cymbal-shop")
	}
	cacheDir := filepath.Join(c.CheckoutPath, ".cache", fmt.Sprintf("microservices-demo-%s", appVersion))
	err := utils.CloneUpstreamRepo(t, appSourceRepoURL, appVersion, cacheDir, c.Logger)
	if err != nil {
		return err
	}

	// Copy upstream microservices-demo base code to target repository
	err = utils.CopyDirectory(cacheDir, targetGitPath)
	if err != nil {
		return err
	}

	// Overlay cymbal-shop 6-appsource configs (cloudbuild.yaml, skaffold.yaml, kubernetes-manifests)
	appSourceDir := filepath.Join(c.EABPath, "examples", "cymbal-shop", "6-appsource", "cymbal-shop")
	if fi, err := os.Stat(appSourceDir); err != nil || !fi.IsDir() {
		return fmt.Errorf("cymbal-shop 6-appsource directory not found at %s", appSourceDir)
	}

	return utils.CopyDirectory(appSourceDir, targetGitPath)
}

// CymbalBankPreparer handles cloning bank-of-anthos, patching shared master overlays, and populating service repos.
type CymbalBankPreparer struct{}

func (p *CymbalBankPreparer) Prepare(t testing.TB, c CommonConf, appSourceRepoURL, appVersion, serviceKey, targetGitPath string) error {
	if appSourceRepoURL == "" {
		return fmt.Errorf("app_source_repo_url is required for cymbal-bank")
	}
	if appVersion == "" {
		return fmt.Errorf("app_version is required for cymbal-bank")
	}
	patchedMasterDir := filepath.Join(c.CheckoutPath, ".cache", fmt.Sprintf("bank-of-anthos-patched-%s", appVersion))
	err := prepareCymbalBankMasterTree(t, c, appSourceRepoURL, appVersion, patchedMasterDir)
	if err != nil {
		return err
	}
	return utils.CopyDirectory(patchedMasterDir, targetGitPath)
}

func prepareCymbalBankMasterTree(t testing.TB, c CommonConf, appSourceRepoURL, appVersion, patchedMasterDir string) error {
	if _, err := os.Stat(patchedMasterDir); err == nil {
		return nil
	}

	cacheDir := filepath.Join(c.CheckoutPath, ".cache", fmt.Sprintf("bank-of-anthos-%s", appVersion))
	err := utils.CloneUpstreamRepo(t, appSourceRepoURL, appVersion, cacheDir, c.Logger)
	if err != nil {
		return err
	}

	// Copy base upstream repository to patched master cache
	err = utils.CopyDirectory(cacheDir, patchedMasterDir)
	if err != nil {
		return err
	}

	appSourceBase := filepath.Join(c.EABPath, "examples", "cymbal-bank", "6-appsource", "cymbal-bank")
	if fi, err := os.Stat(appSourceBase); err != nil || !fi.IsDir() {
		return fmt.Errorf("cymbal-bank 6-appsource directory not found at %s", appSourceBase)
	}

	// 1. Clean default components and copy custom components
	_ = os.RemoveAll(filepath.Join(patchedMasterDir, "src", "components"))
	componentsSrc := filepath.Join(appSourceBase, "components")
	if _, err := os.Stat(componentsSrc); err == nil {
		if err := utils.CopyDirectory(componentsSrc, filepath.Join(patchedMasterDir, "src", "components")); err != nil {
			return err
		}
	}

	// 2. Database overlays
	ledgerDbSrc := filepath.Join(appSourceBase, "ledger-db", "k8s", "overlays")
	if _, err := os.Stat(ledgerDbSrc); err == nil {
		if err := utils.CopyDirectory(ledgerDbSrc, filepath.Join(patchedMasterDir, "src", "ledger", "ledger-db", "k8s", "overlays")); err != nil {
			return err
		}
	}

	accountsDbSrc := filepath.Join(appSourceBase, "accounts-db", "k8s", "overlays")
	if _, err := os.Stat(accountsDbSrc); err == nil {
		if err := utils.CopyDirectory(accountsDbSrc, filepath.Join(patchedMasterDir, "src", "accounts", "accounts-db", "k8s", "overlays")); err != nil {
			return err
		}
	}

	// 3. Service-specific Skaffold and K8s overlays
	serviceOverlayMappings := []struct {
		appSourceSubdir string
		targetSubdir    string
	}{
		{"frontend", filepath.Join("frontend")},
		{"accounts-contacts", filepath.Join("accounts", "contacts")},
		{"accounts-userservice", filepath.Join("accounts", "userservice")},
		{"ledger-balancereader", filepath.Join("ledger", "balancereader")},
		{"ledger-ledgerwriter", filepath.Join("ledger", "ledgerwriter")},
		{"ledger-transactionhistory", filepath.Join("ledger", "transactionhistory")},
	}

	for _, m := range serviceOverlayMappings {
		srcSkaffold := filepath.Join(appSourceBase, m.appSourceSubdir, "skaffold.yaml")
		if _, err := os.Stat(srcSkaffold); err == nil {
			if err := utils.CopyFile(srcSkaffold, filepath.Join(patchedMasterDir, "src", m.targetSubdir, "skaffold.yaml")); err != nil {
				return err
			}
		}

		srcK8s := filepath.Join(appSourceBase, m.appSourceSubdir, "k8s")
		if _, err := os.Stat(srcK8s); err == nil {
			if err := utils.CopyDirectory(srcK8s, filepath.Join(patchedMasterDir, "src", m.targetSubdir, "k8s")); err != nil {
				return err
			}
		}
	}

	// 4. Team Cloud Build configurations
	teamCloudBuilds := []struct {
		team   string
		target string
	}{
		{"frontend", filepath.Join("frontend", "cloudbuild.yaml")},
		{"accounts", filepath.Join("accounts", "cloudbuild.yaml")},
		{"ledger", filepath.Join("ledger", "cloudbuild.yaml")},
	}

	for _, tcb := range teamCloudBuilds {
		srcCB := filepath.Join(appSourceBase, "cloudbuild-files", tcb.team, "cloudbuild.yaml")
		if _, err := os.Stat(srcCB); err == nil {
			if err := utils.CopyFile(srcCB, filepath.Join(patchedMasterDir, "src", tcb.target)); err != nil {
				return err
			}
		}
	}

	// 5. Other overlays (e.g. e2e Dockerfile)
	e2eDocker := filepath.Join(appSourceBase, "other-overlays", "e2e.Dockerfile")
	if _, err := os.Stat(e2eDocker); err == nil {
		targetE2E := filepath.Join(patchedMasterDir, ".github", "workflows", "ui-tests")
		_ = os.MkdirAll(targetE2E, 0755)
		_ = utils.CopyFile(e2eDocker, filepath.Join(targetE2E, "Dockerfile"))
	}

	return nil
}

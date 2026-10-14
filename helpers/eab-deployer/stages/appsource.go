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
	"sync"

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
		return NewCymbalShopPreparer()
	case "cymbal-bank":
		return NewCymbalBankPreparer()
	default:
		return &SelfContainedPreparer{ExampleName: normExample}
	}
}

// SelfContainedPreparer handles examples where source code lives directly inside 6-appsource.
type SelfContainedPreparer struct {
	ExampleName string
}

func (p *SelfContainedPreparer) Prepare(t testing.TB, c CommonConf, _, _, serviceKey, targetGitPath string) error {
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
type CymbalShopPreparer struct {
	mu sync.Mutex
}

func NewCymbalShopPreparer() *CymbalShopPreparer {
	return &CymbalShopPreparer{}
}

func (p *CymbalShopPreparer) Prepare(t testing.TB, c CommonConf, appSourceRepoURL, appVersion, _, targetGitPath string) error {
	if appSourceRepoURL == "" {
		return fmt.Errorf("app_source_repo_url is required for cymbal-shop")
	}
	if appVersion == "" {
		return fmt.Errorf("app_version is required for cymbal-shop")
	}

	cacheDir := filepath.Join(c.CheckoutPath, ".cache", fmt.Sprintf("microservices-demo-%s", appVersion))

	p.mu.Lock()
	err := utils.CloneUpstreamRepo(t, appSourceRepoURL, appVersion, cacheDir, c.Logger)
	p.mu.Unlock()
	if err != nil {
		return err
	}

	// Copy upstream microservices-demo base code to target repository
	if err := utils.CopyDirectory(cacheDir, targetGitPath); err != nil {
		return err
	}

	// Overlay cymbal-shop 6-appsource configs (cloudbuild.yaml, skaffold.yaml, kubernetes-manifests)
	appSourceDir := filepath.Join(c.EABPath, "examples", "cymbal-shop", "6-appsource", "cymbal-shop")
	if fi, err := os.Stat(appSourceDir); err != nil || !fi.IsDir() {
		return fmt.Errorf("cymbal-shop 6-appsource directory not found at %s", appSourceDir)
	}

	return utils.CopyDirectory(appSourceDir, targetGitPath)
}

// OverlayMapping defines a source-to-destination file or directory overlay rule.
type OverlayMapping struct {
	SourceRelPath string
	TargetRelPath string
	IsDirectory   bool
}

// CymbalBankPreparer handles cloning bank-of-anthos, patching shared master overlays, and populating service repos.
type CymbalBankPreparer struct {
	mu sync.Mutex
}

func NewCymbalBankPreparer() *CymbalBankPreparer {
	return &CymbalBankPreparer{}
}

func (p *CymbalBankPreparer) Prepare(t testing.TB, c CommonConf, appSourceRepoURL, appVersion, _, targetGitPath string) error {
	if appSourceRepoURL == "" {
		return fmt.Errorf("app_source_repo_url is required for cymbal-bank")
	}
	if appVersion == "" {
		return fmt.Errorf("app_version is required for cymbal-bank")
	}

	patchedMasterDir := filepath.Join(c.CheckoutPath, ".cache", fmt.Sprintf("bank-of-anthos-patched-%s", appVersion))

	p.mu.Lock()
	err := p.ensurePatchedMasterTree(t, c, appSourceRepoURL, appVersion, patchedMasterDir)
	p.mu.Unlock()
	if err != nil {
		return err
	}

	return utils.CopyDirectory(patchedMasterDir, targetGitPath)
}

func (p *CymbalBankPreparer) ensurePatchedMasterTree(t testing.TB, c CommonConf, appSourceRepoURL, appVersion, patchedMasterDir string) (err error) {
	if _, err := os.Stat(patchedMasterDir); err == nil {
		return nil
	}
	defer func() {
		if err != nil {
			_ = os.RemoveAll(patchedMasterDir)
		}
	}()

	cacheDir := filepath.Join(c.CheckoutPath, ".cache", fmt.Sprintf("bank-of-anthos-%s", appVersion))
	if err := utils.CloneUpstreamRepo(t, appSourceRepoURL, appVersion, cacheDir, c.Logger); err != nil {
		return err
	}

	// Copy base upstream repository to patched master cache
	if err := utils.CopyDirectory(cacheDir, patchedMasterDir); err != nil {
		return err
	}

	appSourceBase := filepath.Join(c.EABPath, "examples", "cymbal-bank", "6-appsource", "cymbal-bank")
	if fi, err := os.Stat(appSourceBase); err != nil || !fi.IsDir() {
		return fmt.Errorf("cymbal-bank 6-appsource directory not found at %s", appSourceBase)
	}

	// 1. Clean default components and frontend k8s manifests before applying enterprise blueprint overlays
	_ = os.RemoveAll(filepath.Join(patchedMasterDir, "src", "components"))
	_ = os.RemoveAll(filepath.Join(patchedMasterDir, "src", "frontend", "k8s"))
	componentsSrc := filepath.Join(appSourceBase, "components")
	if _, err := os.Stat(componentsSrc); err == nil {
		if err := utils.CopyDirectory(componentsSrc, filepath.Join(patchedMasterDir, "src", "components")); err != nil {
			return err
		}
	}

	// 2. Declarative overlays for databases, services, cloud build configs, and test harnesses
	declarativeOverlays := []OverlayMapping{
		// Database overlays
		{SourceRelPath: filepath.Join("ledger-db", "k8s", "overlays"), TargetRelPath: filepath.Join("src", "ledger", "ledger-db", "k8s", "overlays"), IsDirectory: true},
		{SourceRelPath: filepath.Join("accounts-db", "k8s", "overlays"), TargetRelPath: filepath.Join("src", "accounts", "accounts-db", "k8s", "overlays"), IsDirectory: true},

		// Service Skaffold and K8s overlays
		{SourceRelPath: filepath.Join("frontend", "skaffold.yaml"), TargetRelPath: filepath.Join("src", "frontend", "skaffold.yaml"), IsDirectory: false},
		{SourceRelPath: filepath.Join("frontend", "k8s"), TargetRelPath: filepath.Join("src", "frontend", "k8s"), IsDirectory: true},

		{SourceRelPath: filepath.Join("accounts-contacts", "skaffold.yaml"), TargetRelPath: filepath.Join("src", "accounts", "contacts", "skaffold.yaml"), IsDirectory: false},
		{SourceRelPath: filepath.Join("accounts-contacts", "k8s"), TargetRelPath: filepath.Join("src", "accounts", "contacts", "k8s"), IsDirectory: true},

		{SourceRelPath: filepath.Join("accounts-userservice", "skaffold.yaml"), TargetRelPath: filepath.Join("src", "accounts", "userservice", "skaffold.yaml"), IsDirectory: false},
		{SourceRelPath: filepath.Join("accounts-userservice", "k8s"), TargetRelPath: filepath.Join("src", "accounts", "userservice", "k8s"), IsDirectory: true},

		{SourceRelPath: filepath.Join("ledger-balancereader", "skaffold.yaml"), TargetRelPath: filepath.Join("src", "ledger", "balancereader", "skaffold.yaml"), IsDirectory: false},
		{SourceRelPath: filepath.Join("ledger-balancereader", "k8s"), TargetRelPath: filepath.Join("src", "ledger", "balancereader", "k8s"), IsDirectory: true},

		{SourceRelPath: filepath.Join("ledger-ledgerwriter", "skaffold.yaml"), TargetRelPath: filepath.Join("src", "ledger", "ledgerwriter", "skaffold.yaml"), IsDirectory: false},
		{SourceRelPath: filepath.Join("ledger-ledgerwriter", "k8s"), TargetRelPath: filepath.Join("src", "ledger", "ledgerwriter", "k8s"), IsDirectory: true},

		{SourceRelPath: filepath.Join("ledger-transactionhistory", "skaffold.yaml"), TargetRelPath: filepath.Join("src", "ledger", "transactionhistory", "skaffold.yaml"), IsDirectory: false},
		{SourceRelPath: filepath.Join("ledger-transactionhistory", "k8s"), TargetRelPath: filepath.Join("src", "ledger", "transactionhistory", "k8s"), IsDirectory: true},

		// Team Cloud Build pipeline files
		{SourceRelPath: filepath.Join("cloudbuild-files", "frontend", "cloudbuild.yaml"), TargetRelPath: filepath.Join("src", "frontend", "cloudbuild.yaml"), IsDirectory: false},
		{SourceRelPath: filepath.Join("cloudbuild-files", "accounts", "cloudbuild.yaml"), TargetRelPath: filepath.Join("src", "accounts", "cloudbuild.yaml"), IsDirectory: false},
		{SourceRelPath: filepath.Join("cloudbuild-files", "ledger", "cloudbuild.yaml"), TargetRelPath: filepath.Join("src", "ledger", "cloudbuild.yaml"), IsDirectory: false},

		// E2E UI Test Dockerfile
		{SourceRelPath: filepath.Join("other-overlays", "e2e.Dockerfile"), TargetRelPath: filepath.Join(".github", "workflows", "ui-tests", "Dockerfile"), IsDirectory: false},
	}

	if err := applyOverlayMappings(appSourceBase, patchedMasterDir, declarativeOverlays); err != nil {
		return err
	}

	ingressAssets := filepath.Join(c.EABPath, "test", "integration", "appsource", "assets")
	if fi, err := os.Stat(ingressAssets); err == nil && fi.IsDir() {
		if err := utils.CopyDirectory(ingressAssets, filepath.Join(patchedMasterDir, "src", "frontend", "k8s", "overlays", "development")); err != nil {
			return err
		}
	}

	return nil
}

func applyOverlayMappings(sourceBase, targetBase string, overlays []OverlayMapping) error {
	for _, m := range overlays {
		src := filepath.Join(sourceBase, m.SourceRelPath)
		dst := filepath.Join(targetBase, m.TargetRelPath)

		if _, err := os.Stat(src); err != nil {
			continue
		}

		if m.IsDirectory {
			if err := utils.CopyDirectory(src, dst); err != nil {
				return fmt.Errorf("failed copying directory overlay from %s to %s: %w", src, dst, err)
			}
		} else {
			if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
				return fmt.Errorf("failed creating parent directory for %s: %w", dst, err)
			}
			if err := utils.CopyFile(src, dst); err != nil {
				return fmt.Errorf("failed copying file overlay from %s to %s: %w", src, dst, err)
			}
		}
	}
	return nil
}

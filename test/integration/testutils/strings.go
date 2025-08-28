// Copyright 2024-2025 Google LLC
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
	"strings"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
)

var (
	ServicesNames = map[string][]string{
		"cymbal-bank": {
			"accounts-contacts",
			"accounts-userservice",
			"frontend",
			"ledger-balancereader",
			"ledger-ledgerwriter",
			"ledger-transactionhistory",
		},
		"cymbal-shop": {
			"cymbalshop",
		},
		"default-example": {
			"hello-world",
		},
	}

	ServicesWithEnvProject = map[string][]string{
		"cymbal-bank": {
			"userservice",
			"ledgerwriter",
		},
	}

	AppNames = []string{
		"cymbal-bank",
	}
)

func GetLastSplitElement(value string, sep string) string {
	splitted := strings.Split(value, sep)
	return splitted[len(splitted)-1]
}

func EnvNames(t *testing.T) []string {
	branchName := utils.ValFromEnv(t, "TF_VAR_branch_name")
	if branchName == "release-please--branches--main" || strings.HasPrefix(branchName, "test-all/") {
		return []string{
			"development",
			"nonproduction",
			"production",
		}
	} else if branchName == "" {
		return []string{
			"development",
			"nonproduction",
		}
	}
	return []string{
		"development",
	}
}

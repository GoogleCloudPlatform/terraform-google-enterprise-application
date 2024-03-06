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

package appfactory

import (
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/stretchr/testify/assert"
)

func TestAppfactory(t *testing.T) {
	bootstrap := tft.NewTFBlueprintTest(t,
		         tft.WithTFDir("../../../3-appfactory/apps"),
	)

	bootstrap.DefineVerify(func(assert *assert.Assertions) {
		bootstrap.DefaultVerify(assert)

	})
	bootstrap.Test()
}
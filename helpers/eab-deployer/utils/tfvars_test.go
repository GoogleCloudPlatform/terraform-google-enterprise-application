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
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestWriteReadTfvars(t *testing.T) {

	type nested struct {
		Name  string `cty:"name"`
		Value string `cty:"value"`
	}

	type tfvars struct {
		Required string    `hcl:"required"`
		Slice    []string  `hcl:"slice"`
		Optional *string   `hcl:"optional"`
		Nested   *[]nested `hcl:"nested"`
	}

	optional := "no"
	nestedValue := nested{
		Name:  "cloud",
		Value: "GCP",
	}
	tests := []struct {
		name string
		tfv  tfvars
	}{
		{
			name: "required",
			tfv: tfvars{
				Required: "yes",
				Slice:    []string{"one", "two"},
			},
		},
		{
			name: "optional",
			tfv: tfvars{
				Required: "yes",
				Slice:    []string{"one", "two"},
				Optional: &optional,
				Nested:   &[]nested{nestedValue},
			},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			dir := t.TempDir()
			file := filepath.Join(dir, "test.tfvars")
			err := WriteTfvars(file, tt.tfv)
			assert.NoError(t, err)

			var read tfvars
			err = ReadTfvars(file, &read)
			assert.NoError(t, err)
			assert.Equal(t, tt.tfv.Required, read.Required, "Required value should be %s", tt.tfv.Required)
			assert.Equal(t, tt.tfv.Optional, read.Optional, "Optional value should be equal")
			assert.Equal(t, tt.tfv.Nested, read.Nested, "Nested value should be equal")
			assert.Len(t, read.Slice, 2, "Slice should have 2 elements")
			assert.Contains(t, read.Slice, "one", "Slice should have element 'one'")
			assert.Contains(t, read.Slice, "two", "Slice should have element 'two'")
			if tt.name == "optional" {
				assert.Equal(t, *read.Optional, "no", "Optional value should be 'no'")
				assert.Contains(t, *read.Nested, nestedValue, "Should have the nested value")
			} else {
				assert.Nil(t, read.Optional, "Optional value should be 'nil'")
				assert.Nil(t, read.Nested, "Nested value should be 'nil'")
			}
		})
	}
}

func TestWriteReadNCCConfig(t *testing.T) {
	type nccConfig struct {
		EnableNCC                *bool             `hcl:"enable_ncc" cty:"enable_ncc"`
		HubURI                   *string           `hcl:"hub_uri" cty:"hub_uri"`
		SpokeGroup               *string           `hcl:"spoke_group" cty:"spoke_group"`
		SpokeName                *string           `hcl:"spoke_name" cty:"spoke_name"`
		SpokeDescription         *string           `hcl:"spoke_description" cty:"spoke_description"`
		SpokeLabels              map[string]string `hcl:"spoke_labels" cty:"spoke_labels"`
		SpokeExcludeExportRanges []string          `hcl:"spoke_exclude_export_ranges" cty:"spoke_exclude_export_ranges"`
		SpokeIncludeExportRanges []string          `hcl:"spoke_include_export_ranges" cty:"spoke_include_export_ranges"`
	}

	type rootTfvars struct {
		ProjectID string     `hcl:"project_id"`
		NCCConfig *nccConfig `hcl:"ncc_config"`
	}

	enableNCC := true
	hubURI := "projects/test-project/locations/global/hubs/test-hub"
	spokeGroup := "edge"
	spokeName := "vpc-spoke"
	spokeDesc := "NCC spoke for testing"

	input := rootTfvars{
		ProjectID: "my-project",
		NCCConfig: &nccConfig{
			EnableNCC:                &enableNCC,
			HubURI:                   &hubURI,
			SpokeGroup:               &spokeGroup,
			SpokeName:                &spokeName,
			SpokeDescription:         &spokeDesc,
			SpokeLabels:              map[string]string{"env": "test"},
			SpokeExcludeExportRanges: []string{"10.0.0.0/16"},
			SpokeIncludeExportRanges: []string{"192.168.0.0/24"},
		},
	}

	dir := t.TempDir()
	file := filepath.Join(dir, "ncc_test.tfvars")
	err := WriteTfvars(file, input)
	assert.NoError(t, err)

	var read rootTfvars
	err = ReadTfvars(file, &read)
	assert.NoError(t, err)
	assert.Equal(t, input.ProjectID, read.ProjectID)
	assert.NotNil(t, read.NCCConfig)
	assert.Equal(t, *input.NCCConfig.EnableNCC, *read.NCCConfig.EnableNCC)
	assert.Equal(t, *input.NCCConfig.HubURI, *read.NCCConfig.HubURI)
	assert.Equal(t, *input.NCCConfig.SpokeGroup, *read.NCCConfig.SpokeGroup)
	assert.Equal(t, *input.NCCConfig.SpokeName, *read.NCCConfig.SpokeName)
	assert.Equal(t, *input.NCCConfig.SpokeDescription, *read.NCCConfig.SpokeDescription)
	assert.Equal(t, input.NCCConfig.SpokeLabels, read.NCCConfig.SpokeLabels)
	assert.Equal(t, input.NCCConfig.SpokeExcludeExportRanges, read.NCCConfig.SpokeExcludeExportRanges)
	assert.Equal(t, input.NCCConfig.SpokeIncludeExportRanges, read.NCCConfig.SpokeIncludeExportRanges)
}

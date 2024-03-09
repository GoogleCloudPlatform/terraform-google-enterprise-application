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

package multitenant

import (
	"fmt"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestMultitenant(t *testing.T) {

	for _, envName := range []string{
		"development",
		"non-production",
		"production",
	} {
		envName := envName
		t.Run(envName, func(t *testing.T) {
			t.Parallel()
			multitenant := tft.NewTFBlueprintTest(t,
				tft.WithTFDir(fmt.Sprintf("../../../2-multitenant/envs/%s", envName)),
			)

			multitenant.DefineVerify(func(assert *assert.Assertions) {
				multitenant.DefaultVerify(assert)

				// Project IDs
				clusterProjectID := multitenant.GetStringOutput("cluster_project_id")
				fleetProjectID := multitenant.GetStringOutput("fleet_project_id")
				// networkProjectID := multitenant.GetStringOutput("network_project_id")

				// GKE Cluster
				clusterRegions := terraform.OutputMap(t, multitenant.GetTFOptions(), "clusters_ids")
				clusterIds := terraform.OutputMap(t, multitenant.GetTFOptions(), "clusters_ids")
				listMonitoringEnabledComponents := []string{
					"SYSTEM_COMPONENTS",
					"DEPLOYMENT",
				}

				for _, region := range clusterRegions {
					for _, id := range clusterIds {
						clusterOp := gcloud.Runf(t, "container clusters describe %s --region %s --project %s", id, region, clusterProjectID)
						// NodePool
						assert.Equal("node-pool-1", clusterOp.Get("nodePools.0.name").String(), "NodePool name should be node-pool-1")
						assert.Equal("SURGE", clusterOp.Get("nodePools.0.upgradeSettings.strategy").String(), "NodePool strategy should SURGE")
						assert.Equal("1", clusterOp.Get("nodePools.0.upgradeSettings.maxSurge").String(), "NodePool max surge should be 1")
						assert.Equal("BALANCED", clusterOp.Get("nodePools.0.autoscaling.locationPolicy").String(), "NodePool auto scaling location prolicy should be BALANCED")
						assert.True(clusterOp.Get("nodePools.0.autoscaling.enabled").Bool(), "NodePool auto scaling should be enabled (true)")
						// Cluster
						assert.Equal(fleetProjectID, clusterOp.Get("fleet.project").String(), fmt.Sprintf("Cluster %s Fleet Project should be %s", id, fleetProjectID))
						clusterEnabledComponents := utils.GetResultStrSlice(clusterOp.Get("monitoringConfig.componentConfig.enableComponents").Array())
						assert.Contains(listMonitoringEnabledComponents, clusterEnabledComponents, fmt.Sprintf("Cluster %s should have Monitoring Enabled Components: SYSTEM_COMPONENTS and DEPLOYMENT", id))
						assert.True(clusterOp.Get("monitoringConfig.componentConfig.managedPrometheusConfig").Bool(), fmt.Sprintf("Cluster %s should have Managed Prometheus Config equals True", id))
					}
				}
			})

			multitenant.Test()
		})
	}
}

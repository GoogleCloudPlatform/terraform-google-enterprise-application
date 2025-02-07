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

package hpc

import (
	"fmt"
	"strings"
	"testing"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/terraform-google-modules/enterprise-application/test/integration/testutils"
)

func installKueue(t *testing.T, options *k8s.KubectlOptions) (string, error) {
	return k8s.RunKubectlAndGetOutputE(t, options, "apply", "--server-side", "-f", "https://github.com/kubernetes-sigs/kueue/releases/download/v0.10.1/manifests.yaml")
}

func TestHPCMonteCarlo(t *testing.T) {
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	// retrieve cluster location and fleet membership from 2-multitenant
	clusterProjectId := multitenant.GetJsonOutput("cluster_project_id").String()
	clusterLocation := multitenant.GetJsonOutput("cluster_regions").Array()[0].String()
	clusterMembership := multitenant.GetJsonOutput("cluster_membership_ids").Array()[0].String()

	// extract clusterName from fleet membership id
	splitClusterMembership := strings.Split(clusterMembership, "/")
	clusterName := splitClusterMembership[len(splitClusterMembership)-1]

	testutils.ConnectToFleet(t, clusterName, clusterLocation, clusterProjectId)
	k8sOpts := k8s.NewKubectlOptions(fmt.Sprintf("connectgateway_%s_%s_%s", clusterProjectId, clusterLocation, clusterName), "", "")

	_, err := installKueue(t, k8sOpts)
	if err != nil {
		t.Fatal(err)
	}
	t.Run("hpc-monte-carlo-simulation Test", func(t *testing.T) {
		out, err := k8s.RunKubectlAndGetOutputE(t, k8sOpts, "wait", "deploy/kueue-controller-manager", "-n", "kueue-system", "--for=condition=available", "--timeout=5m")
		if err != nil {
			t.Fatal(err)
		}
		t.Logf("%s", out)
	})
}

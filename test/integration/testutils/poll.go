// Copyright 2025-2026 Google LLC
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
	"errors"
	"fmt"
	"slices"
	"testing"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/tidwall/gjson"
)

// PollCloudBuild polls Cloud Build list command until the build completes with SUCCESS or FAILURE.
// If onRetry callback is provided, it is invoked every 3 attempts when no build is found.
// If onRetry returns a non-empty string, it updates the command used to query builds.
func PollCloudBuild(t testing.TB, cmd string, region string, serviceName string, onRetry ...func() string) func() (bool, error) {
	retriesBuildTrigger := 1
	currentCmd := cmd
	return func() (bool, error) {
		build := gcloud.Runf(t, currentCmd).Array()
		if len(build) < 1 {
			if retriesBuildTrigger%3 == 0 && len(onRetry) > 0 && onRetry[0] != nil {
				newCmd := onRetry[0]()
				if newCmd != "" {
					currentCmd = newCmd
				}
			}
			retriesBuildTrigger++
			return true, nil
		}
		latestWorkflowRunStatus := build[0].Get("status").String()
		switch latestWorkflowRunStatus {
		case "SUCCESS":
			return false, nil
		case "FAILURE":
			logsCmd := fmt.Sprintf("builds log %s --project=%s --region=%s", build[0].Get("id").String(), build[0].Get("projectId").String(), region)
			logs := gcloud.RunCmd(t, logsCmd)
			t.Logf("%s build-log: %s", serviceName, logs)
			return false, errors.New("build failed")
		}
		return true, nil
	}
}

// PollCloudDeployRelease polls Cloud Deploy releases until a release is found and stores its name in releaseName if provided.
func PollCloudDeployRelease(t testing.TB, cmd string, releaseName *string) func() (bool, error) {
	return func() (bool, error) {
		releases := gcloud.Runf(t, cmd).Array()
		if len(releases) == 0 {
			return true, nil
		}
		if releaseName != nil {
			*releaseName = releases[0].Get("name").String()
		}
		return false, nil
	}
}

// PollCloudDeploy polls Cloud Deploy rollouts until the rollout reaches SUCCEEDED or unretryable failure.
// If a retryable deployment error occurs (e.g. cluster scaling/stabilizing), it triggers a rollout retry.
func PollCloudDeploy(t testing.TB, cmd string, projectID string, serviceName string, region string, releaseName string) func() (bool, error) {
	return func() (bool, error) {
		rollouts := gcloud.Runf(t, cmd).Array()
		if len(rollouts) < 1 {
			return true, nil
		}
		latestRolloutState := rollouts[0].Get("state").String()
		rolloutName := GetLastSplitElement(rollouts[0].Get("name").String(), "/")
		releaseNameFinal := GetLastSplitElement(releaseName, "/")
		if latestRolloutState == "SUCCEEDED" {
			t.Logf("Rollout finished successfully %s. \n", rollouts[0].Get("targetId"))
			return false, nil
		} else if slices.Contains([]string{"IN_PROGRESS", "PENDING_RELEASE"}, latestRolloutState) {
			t.Logf("Rollout in progress %s. \n", rollouts[0].Get("targetId"))
			return true, nil
		} else {
			buildID := rollouts[0].Get("deployingBuild").String()
			if buildID == "" {
				buildsCmd := fmt.Sprintf("builds list --project=%s --region=%s --filter='status=FAILURE AND tags:%s'", projectID, region, releaseNameFinal)
				builds := gcloud.Run(t, buildsCmd).Array()
				if len(builds) > 0 {
					buildID = builds[0].Get("id").String()
				}
			}
			if buildID != "" {
				logsCmd := fmt.Sprintf("builds log %s --project=%s --region=%s", buildID, projectID, region)
				logs := gcloud.RunCmd(t, logsCmd)
				t.Logf("%s build-log: %s", serviceName, logs)
				isRetryable, message := IsDeploymentRetryableError(logs)
				if isRetryable {
					t.Logf("Re-trying rollout: %s", message)
					gcloud.Run(t, fmt.Sprintf("deploy rollouts retry-job %s --project=%s --delivery-pipeline=%s --region=%s --release=%s --phase-id=stable --job-id=deploy", rolloutName, projectID, serviceName, region, releaseNameFinal))
					return true, nil
				}
			}
			return false, fmt.Errorf("rollout %s", latestRolloutState)
		}
	}
}

// PromoteAndPollCloudDeploy promotes a Cloud Deploy release across targets sequentially,
// polling each rollout until completion before promoting to the next target.
// targets can be []string, []gjson.Result, or gjson.Result.
// Optional sleepBetweenRetries parameter specifies duration between poll retries (defaults to 60s).
func PromoteAndPollCloudDeploy(t testing.TB, projectID string, serviceName string, region string, releaseName string, targets any, sleepBetweenRetries ...time.Duration) {
	targetList := extractTargetStrings(targets)
	sleepDuration := 60 * time.Second
	if len(sleepBetweenRetries) > 0 && sleepBetweenRetries[0] > 0 {
		sleepDuration = sleepBetweenRetries[0]
	}
	for i, targetID := range targetList {
		if i > 0 {
			promoteCmd := fmt.Sprintf("deploy releases promote --project=%s --release=%s --delivery-pipeline=%s --region=%s --to-target=%s -q", projectID, releaseName, serviceName, region, targetID)
			t.Logf("Promoting release to next target: %s", targetID)
			gcloud.Runf(t, promoteCmd)
		}
		rolloutListCmd := fmt.Sprintf("deploy rollouts list --project=%s --delivery-pipeline=%s --region=%s --release=%s --filter targetId=%s", projectID, serviceName, region, releaseName, targetID)
		utils.Poll(t, PollCloudDeploy(t, rolloutListCmd, projectID, serviceName, region, releaseName), 100, sleepDuration)
	}
}

func extractTargetStrings(targets any) []string {
	switch v := targets.(type) {
	case []string:
		return v
	case []gjson.Result:
		res := make([]string, len(v))
		for i, item := range v {
			res[i] = item.String()
		}
		return res
	case gjson.Result:
		arr := v.Array()
		res := make([]string, len(arr))
		for i, item := range arr {
			res[i] = item.String()
		}
		return res
	default:
		return nil
	}
}

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

package gcp

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"maps"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/gcloud"
	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/utils"
	"github.com/mitchellh/go-testing-interface"
	"github.com/tidwall/gjson"
	"google.golang.org/api/cloudbuild/v1"
	"google.golang.org/api/option"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/test/integration/testutils"
)

const (
	BuildStatusQueued      = "QUEUED"
	BuildStatusWorking     = "WORKING"
	BuildStatusSuccess     = "SUCCESS"
	BuildStatusFailure     = "FAILURE"
	BuildStatusCancelled   = "CANCELLED"
	ReleaseStatusWorking   = "IN_PROGRESS"
	ReleaseStatusQueued    = "PENDING_RELEASE"
	ReleaseStatusSuccess   = "SUCCEEDED"
	ReleaseStatusFailure   = "FAILED"
	ReleaseStatusCancelled = "CANCELLED"
)

type RetryOp struct {
	Type  string `json:"@type"`
	Build Build  `json:"build"`
}
type Build struct {
	ID         string `json:"id"`
	Status     string `json:"status"`
	CreateTime string `json:"createTime"`
}

var (
	retryRegexp = map[*regexp.Regexp]string{}
	// ctx         = context.Background()
)

func init() {
	for e, m := range testutils.RetryableTransientErrors {
		r, err := regexp.Compile(fmt.Sprintf("(?s)%s", e)) //(?s) enables dot (.) to match newline.
		if err != nil {
			panic(fmt.Sprintf("failed to compile regex %s: %s", e, err.Error()))
		}
		retryRegexp[r] = m
	}
}

type GCP struct {
	Runf            func(t testing.TB, cmd string, args ...interface{}) gjson.Result
	RunCmd          func(t testing.TB, cmd string, args ...interface{}) string
	TriggerNewBuild func(t testing.TB, ctx context.Context, buildName string) (string, error)
	sleepTime       time.Duration
}

// runCmd is a wrapper around gcloud.RunCmd because the original function has an input with a private type
func runCmd(t testing.TB, cmd string, args ...interface{}) string {
	return gcloud.RunCmd(t, utils.StringFromTextAndArgs(append([]interface{}{cmd}, args...)...))
}

// triggerNewBuild triggers a new build based on the build provided
func triggerNewBuild(t testing.TB, ctx context.Context, buildName string) (string, error) {

	buildService, err := cloudbuild.NewService(ctx, option.WithScopes(cloudbuild.CloudPlatformScope))
	if err != nil {
		return "", fmt.Errorf("failed to create Cloud Build service: %w", err)
	}
	retryOperation, err := buildService.Projects.Locations.Builds.Retry(buildName, &cloudbuild.RetryBuildRequest{}).Do()
	if err != nil {
		return "", fmt.Errorf("failed to retry build: %w", err)
	}

	var data RetryOp
	err = json.Unmarshal(retryOperation.Metadata, &data)
	if err != nil {
		return "", fmt.Errorf("error unmarshaling retry operation metadata: %v", err)
	}

	return data.Build.ID, nil
}

// NewGCP creates a new wrapper for Google Cloud Platform CLI.
func NewGCP() GCP {
	return GCP{
		Runf:            gcloud.Runf,
		RunCmd:          runCmd,
		TriggerNewBuild: triggerNewBuild,
		sleepTime:       20,
	}
}

// GetBuilds gets all Cloud Build builds form a project and region that satisfy the given filter.
func (g GCP) GetBuilds(t testing.TB, projectID, region, filter string) map[string]string {
	var result = map[string]string{}
	builds := g.Runf(t, "builds list --project %s --region %s --filter %s", projectID, region, filter).Array()
	if len(builds) > 0 {
		for _, b := range builds {
			result[b.Get("id").String()] = b.Get("status").String()
		}
	}
	return result
}

// GetLastBuildStatus gets the status of the last build form a project and region that satisfy the given filter.
func (g GCP) GetLastBuildStatus(t testing.TB, projectID, region, filter string) (string, string) {
	builds := g.Runf(t, "builds list --project %s --region %s --limit 1 --sort-by ~createTime --filter %s", projectID, region, filter).Array()
	if len(builds) == 0 {
		return "", ""
	}
	build := builds[0]
	return build.Get("status").String(), build.Get("id").String()
}

// GetBuildStatus gets the status of the given build
func (g GCP) GetBuildStatus(t testing.TB, projectID, region, buildID string) string {
	return g.Runf(t, "builds describe %s  --project %s --region %s", buildID, projectID, region).Get("status").String()
}

// GetRunningBuildID gets the current build running for the given project, region, and filter
func (g GCP) GetRunningBuildID(t testing.TB, projectID, region, filter string, retryGetBuild int) string {
	currentRetry := 1
	time.Sleep(g.sleepTime * time.Second)
	builds := g.GetBuilds(t, projectID, region, filter)
	if len(builds) == 0 && currentRetry <= retryGetBuild {
		return g.GetRunningBuildID(t, projectID, region, filter, retryGetBuild-currentRetry)
	}
	for id, status := range builds {
		if status == BuildStatusQueued || status == BuildStatusWorking {
			return id
		}
	}
	return ""
}

// GetFinalBuildState gets the terminal status of the given build. It will wait if build is not finished.
func (g GCP) GetFinalBuildState(t testing.TB, projectID, region, buildID string, maxBuildRetry int) (string, error) {
	var status string
	count := 0
	fmt.Printf("waiting for build %s execution.\n", buildID)
	status = g.GetBuildStatus(t, projectID, region, buildID)
	fmt.Printf("build status is %s\n", status)
	for status != BuildStatusSuccess && status != BuildStatusFailure && status != BuildStatusCancelled {
		fmt.Printf("build status is %s\n", status)
		if count >= maxBuildRetry {
			return "", fmt.Errorf("timeout waiting for build '%s' execution", buildID)
		}
		count = count + 1
		time.Sleep(g.sleepTime * time.Second)
		status = g.GetBuildStatus(t, projectID, region, buildID)
	}
	fmt.Printf("final build status is %s\n", status)
	return status, nil
}

// GetRollouts gets all Cloud Deploy Rollouts form a project and region that satisfy the given filter.
func (g GCP) GetRolloutsStatus(t testing.TB, projectID, region, service, releaseFullName, targetID string) string {
	rollout := g.Runf(t, "deploy rollouts list --project=%s --delivery-pipeline=%s --region=%s --release=%s --filter targetId=%s", projectID, service, region, releaseFullName, targetID).Array()
	if len(rollout) > 0 {
		return rollout[0].Get("state").String()
	}
	return ""
}

// GetFinalRolloutState gets the terminal status of the given rollout. It will wait if build is not finished.
func (g GCP) GetFinalRolloutState(t testing.TB, projectID, region, serviceName, releaseFullName, targetID string, maxRetry int) (string, error) {
	var status string
	count := 0
	fmt.Printf("waiting for rollout %s execution.\n", releaseFullName)
	status = g.GetRolloutsStatus(t, projectID, region, serviceName, releaseFullName, targetID)
	fmt.Printf("rollout status is %s\n", status)
	for status != ReleaseStatusSuccess && status != ReleaseStatusFailure && status != ReleaseStatusCancelled {
		fmt.Printf("release status is %s\n", status)
		if count >= maxRetry {
			return "", fmt.Errorf("timeout waiting for release '%s' execution", releaseFullName)
		}
		count = count + 1
		time.Sleep(g.sleepTime * time.Second)
		status = g.GetRolloutsStatus(t, projectID, region, serviceName, releaseFullName, targetID)
	}
	fmt.Printf("final rollout status is %s\n", status)
	return status, nil
}

// WaitBuildSuccess waits for the current build in a repo to finish.
func (g GCP) WaitBuildSuccess(t testing.TB, project, region, repo, commitSha, failureMsg string, maxBuildRetry, maxErrorRetries int, timeBetweenErrorRetries time.Duration) error {
	var filter, status, build string
	var timeoutErr, err error
	ctx := context.Background()

	if commitSha == "" {
		filter = fmt.Sprintf("source.repoSource.repoName:%s", repo)
	} else {
		filter = fmt.Sprintf("substitutions.COMMIT_SHA:%s", commitSha)
	}

	build = g.GetRunningBuildID(t, project, region, filter, 5)
	for i := 0; i < maxErrorRetries; i++ {
		if build != "" {
			status, timeoutErr = g.GetFinalBuildState(t, project, region, build, maxBuildRetry)
			if timeoutErr != nil {
				return timeoutErr
			}
		} else {
			status, build = g.GetLastBuildStatus(t, project, region, filter)
			if build == "" {
				return fmt.Errorf("no build found for filter: %s", filter)
			}
		}

		if status != BuildStatusSuccess {
			if !g.IsRetryableError(t, project, region, build) {
				return fmt.Errorf("%s\nSee:\nhttps://console.cloud.google.com/cloud-build/builds;region=%s/%s?project=%s\nfor details", failureMsg, region, build, project)
			}
			fmt.Println("build failed with retryable error. a new build will be triggered.")
		} else {
			return nil // Build succeeded
		}

		// Trigger a new build
		build, err = g.TriggerNewBuild(t, ctx, fmt.Sprintf("projects/%s/locations/%s/builds/%s", project, region, build))
		if err != nil {
			return fmt.Errorf("failed to trigger new build (attempt %d/%d): %w", i+1, maxErrorRetries, err)
		}
		fmt.Printf("triggered new build with ID: %s (attempt %d/%d)\n", build, i+1, maxErrorRetries)
		if i < maxErrorRetries-1 {
			time.Sleep(timeBetweenErrorRetries) // Wait before retrying
		}
	}
	return fmt.Errorf("%s\nbuild failed after %d retries.\nSee Cloud Build logs for details", failureMsg, maxErrorRetries)
}

// IsRetryableError checks the logs of a failed Cloud Build build
// and verify if the error is a transient one and can be retried
func (g GCP) IsRetryableError(t testing.TB, projectID, region, build string) bool {
	logs := g.GetBuildLogs(t, projectID, region, build)
	found := false
	for pattern, msg := range retryRegexp {
		if pattern.MatchString(logs) {
			found = true
			fmt.Printf("error '%s' is worth of a retry\n", msg)
			break
		}
	}
	return found
}

// GetBuildLogs get the execution logs of the given build
func (g GCP) GetBuildLogs(t testing.TB, projectID, region, buildID string) string {
	return g.RunCmd(t, "builds log %s --project %s --region %s", buildID, projectID, region)
}

// WaitReleaseSuccess waits for the current release in a repo to finish.
func (g GCP) WaitReleaseSuccess(t testing.TB, project, region, serviceName, commitSha, failureMsg string, maxRetry int) error {

	releaseFullName := fmt.Sprintf("projects/%s/locations/%s/deliveryPipelines/%s/releases/%s-%s", project, region, serviceName, serviceName, commitSha)

	releaseTargets := slices.Collect(maps.Keys(g.GetRelease(t, releaseFullName).Get("targetArtifacts").Map()))
	if len(releaseTargets) > 0 {
		for i, targetID := range releaseTargets {
			status, err := g.GetFinalRolloutState(t, project, region, serviceName, releaseFullName, targetID, maxRetry)
			if err != nil {
				return err
			}
			if status != ReleaseStatusSuccess {
				return fmt.Errorf("%s\nSee:\nhttps://console.cloud.google.com/deploy/delivery-pipelines?project=%s\nfor details.\n", failureMsg, project)
			}
			if status == ReleaseStatusSuccess && i+1 < len(releaseTargets) {
				g.PromoteRelease(t, releaseFullName, serviceName, region, releaseTargets[i+1])
			}
		}
	}
	return nil
}

// GetRelease waits for the current release.
func (g GCP) GetRelease(t testing.TB, releaseFullName string) gjson.Result {
	return g.Runf(t, "deploy releases describe %s", releaseFullName).Array()[0]
}

// PromoteRelease promote for the current release.
func (g GCP) PromoteRelease(t testing.TB, releaseFullName, serviceName, region, nextTargetId string) gjson.Result {
	return g.Runf(t, "deploy releases promote --release=%s --delivery-pipeline=%s --region=%s --to-target=%s", releaseFullName, serviceName, region, nextTargetId)
}

// HasSccNotification checks if a Security Command Center notification exists
func (g GCP) HasSccNotification(t testing.TB, orgID, sccName string) bool {
	filter := fmt.Sprintf("name=organizations/%s/notificationConfigs/%s", orgID, sccName)
	scc := g.Runf(t, "scc notifications list organizations/%s --filter %s --quiet", orgID, filter).Array()
	if len(scc) == 0 {
		return false
	}
	return testutils.GetLastSplitElement(scc[0].Get("name").String(), "/") == sccName
}

// HasTagKey  checks if a Tag Key exists
func (g GCP) HasTagKey(t testing.TB, orgID, tag string) bool {
	filter := fmt.Sprintf("shortName=%s", tag)
	tags := g.Runf(t, "resource-manager tags keys list --parent organizations/%s --filter %s ", orgID, filter).Array()
	if len(tags) == 0 {
		return false
	}
	return tags[0].Get("shortName").String() == tag
}

// EnableApis enables the apis in the given project
func (g GCP) EnableApis(t testing.TB, project string, apis []string) {
	g.Runf(t, "services enable %s --project %s", strings.Join(apis, " "), project)
}

// IsApiEnabled checks if the api is enabled in the given project
func (g GCP) IsApiEnabled(t testing.TB, project, api string) bool {
	filter := fmt.Sprintf("config.name=%s", api)
	return len(g.Runf(t, "services list --enabled --project %s --filter %s", project, filter).Array()) > 0
}

// IsApiEnabled checks if the api is enabled in the given project
func (g GCP) GetSecretValue(t testing.TB, secretID string) string {
	secret := g.Runf(t, "secrets versions access %s/versions/latest", secretID)
	decoded, err := base64.StdEncoding.DecodeString(secret.Get("payload.data").String())
	if err != nil {
		fmt.Printf("Error decoding string: %s", err.Error())
	}
	return string(decoded)
}

// IsComponentInstalled checks if a given gcloud component is installed
func (g GCP) IsComponentInstalled(t testing.TB, componentID string) bool {
	filter := fmt.Sprintf("\"id='%s'\"", componentID)
	components := g.Runf(t, "components list --filter %s", filter).Array()
	if len(components) == 0 {
		return false
	}
	return components[0].Get("state.name").String() != "Not Installed"
}

func (g GCP) GetRolePermissions(t testing.TB, roleName string) ([]string, error) {
	result := g.Runf(t, "iam roles describe %s", roleName)

	permissions := []string{}
	for _, permission := range result.Get("includedPermissions").Array() {
		permissions = append(permissions, permission.String())
	}
	return permissions, nil
}

func (g GCP) GetAuthToken(t testing.TB) string {
	result := g.Runf(t, "auth print-access-token")

	return result.Get("token").String()
}

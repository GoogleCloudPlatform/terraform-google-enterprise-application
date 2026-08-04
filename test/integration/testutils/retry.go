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

package testutils

import "regexp"

var (
	RetryableTransientErrors = map[string]string{
		// Error 409: unable to queue the operation
		".*Error 409.*unable to queue the operation.*": "Unable to queue operation.",

		// Error code 409 for concurrent policy changes.
		".*Error 409.*There were concurrent policy changes.*": "Concurrent policy changes.",

		// Error 403: Compute Engine API has not been used in project {} before or it is disabled.
		".*Error 403.*Compute Engine API has not been used in project.*": "Compute Engine API not enabled",

		// Error 403: Kubernetes Engine API has not been used in project {} before or it is disabled.
		".*Error 403.*Kubernetes Engine API is not enabled for this project*": "Kubernetes Engine API not enabled",

		// google_gke_hub_feature - Error: Error waiting to create Feature: Error waiting for Creating Feature: Error code 13, message: an internal error has occurred
		".*Error waiting for Creating Feature: Error code 13, message: an internal error has occurred*.": "Error creating feature",

		".*Error waiting for Creating Connection: Error code 9, message: Failed to verify authorizer_credential.*": "servicedirectory.networks.access propagation time",

		// Request had invalid authentication credentials.*
		".*Request had invalid authentication credentials.*": "Request had invalid authentication credentials.",

		// generic::permission_denied: Request is prohibited by organization's policy.
		".*Request is prohibited by organization's policy.*": "VPC-SC propagation.",

		".*does not match the eTag of the current version.*": "VPC-SC eTag consistency.",

		".*Error code 3, message: Request contains an invalid argument.*": "Invalid Argument on Artifact Registry Creation",

		".*another operation is in progress on this scope.*": "another operation is in progress on this scope",

		".*Error when reading or editing ServicePerimeterResource.*": "Propagation issues on Service Perimeter.",

		".*Error when reading or editing AccessLevelCondition.*": "Propagation issues on Access Level.",

		".*Error 400.*Invalid Directional Policies set in Perimeter.*": "Propagation issues on Service Perimeter.",

		".*Error 400.*@.*.iam.gserviceaccount.com.*is invalid or non-existent.*": "Service Agent propagation.",

		".*Error 400.*@.*.iam.gserviceaccount.com.*does not exist.*": "Service Agent propagation.",

		".*Error 400: Identity Pool does not exist (.*).*": "Identity pool propagation.",

		".*dial tcp: lookup.*.sslip.io on.*: server misbehaving.*": "VM Gitlab issues.",

		".*Error 400.*The subnetwork resource.*projects/.*/regions/.*/subnetworks/.*is already being used by.*, resourceInUseByAnotherResource": "Destroy resources usage propagation issues",

		".*The network resource.*projects/.*/global/networks/.*is already being used by.*": "Destroy resources usage propagation issues",

		".*Error waiting for Disabling Shared VPC Resource: The resource.*.is still linked to shared VPC host.*": "Destroy resources usage propagation issues",

		".*Error 400.*Invalid value for field.*resource.networkInterfaces[0].subnetwork.*:.*projects/.*/regions/.*/subnetworks/.*. The referenced subnetwork resource cannot be found.*": "Network propagation",

		".*Error: Error creating FeatureMembership: Resource already exists - apply blocked by lifecycle params.*": "Duplicated membership request",

		".*502.*": "Bad Gateway",

		".*Error 400: Feature has associated resources that should be cleaned up before deletion.*": "Waiting Fleetscope service cleanup",

		".*Error waiting for deleting GKE cluster.*": "Error waiting for deleting GKE cluster: Calling fleet operation service DeleteMembership, please ensure fleet service account has access to the project.",
     ".*Could not connect to server.*": "Network error.",
	}

	RetryableDeploymentErrors = map[string]string{
		".*context deadline exceeded.*": "Timeout connection.",
		".*502.*":                       "Bad Gateway",
		".*Waiting for deployments to stabilize.*":      "Waiting for deployments to stabilize.",
		".*Insufficient memory.*":                       "Waiting cluster to scale up - memory.",
		".*Insufficient CPU.*":                          "Waiting cluster to scale up - CPU.",
		".*didn't match Pod's node affinity/selector.*": "Waiting cluster to scale up - machine/GPU type.",
		".*FailedScaleUp.*":                             "Waiting cluster to scale up - Resources availability.",
		".*Error from server \\(AlreadyExists\\).*":         "Resource already exists, waiting stabilize.",
	}
)

var compiledRetryableErrors = make(map[*regexp.Regexp]string)

func init() {
	// Compile all regex patterns once and store them
	for pattern, msg := range RetryableDeploymentErrors {
		compiledRegex := regexp.MustCompile(pattern)
		compiledRetryableErrors[compiledRegex] = msg
	}
}

// IsDeploymentRetryableError checks the error using pre-compiled regular expressions
func IsDeploymentRetryableError(errMessage string) (bool, string) {
	for regex, msg := range compiledRetryableErrors {
		// MatchString on a compiled regex is much faster
		if regex.MatchString(errMessage) {
			return true, msg
		}
	}

	return false, ""
}

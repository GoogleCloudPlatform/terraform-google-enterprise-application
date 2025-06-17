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

var (
	RetryableTransientErrors = map[string]string{
		// Error 409: unable to queue the operation
		".*Error 409.*unable to queue the operation": "Unable to queue operation.",

		// Error code 409 for concurrent policy changes.
		".*Error 409.*There were concurrent policy changes.*": "Concurrent policy changes.",

		// Error 403: Compute Engine API has not been used in project {} before or it is disabled.
		".*Error 403.*Compute Engine API has not been used in project.*": "Compute Engine API not enabled",

		// Error 403: Kubernetes Engine API has not been used in project {} before or it is disabled.
		".*Error 403: Kubernetes Engine API is not enabled for this project*": "Kubernetes Engine API not enabled",

		// Error 400: Service account service-{}@gcp-sa-mcsd.iam.gserviceaccount.com does not exist.*"
		".*Error 400: Service account service-.*@gcp-sa-mcsd.iam.gserviceaccount.com does not exist.*": "Multi-cluster Service Discovery Service Account does not exist.",

		".*Error waiting for Creating Connection: Error code 9, message: Failed to verify authorizer_credential.*.": "servicedirectory.networks.access propagation time",

		// Request had invalid authentication credentials.*
		".*Request had invalid authentication credentials.*": "Request had invalid authentication credentials.",

		// Error waiting for Creating Repository: Error code 13, message: Internal error encountered.
		".Internal error encountered*": "Internal error encountered",

		// generic::permission_denied: Request is prohibited by organization's policy.
		".*Request is prohibited by organization's policy*.": "VPC-SC propagation.",

		".*does not match the eTag of the current version*": "VPC-SC eTag consistency.",

		".*Error: Error waiting to create Repository: Error waiting for Creating Repository: Error code 3, message: Request contains an invalid argument.*.": "Invalid Argument on Artifact Registry Creation",

		".*another operation is in progress on this scope*.": "another operation is in progress on this scope",

		".*Error when reading or editing ServicePerimeterResource*": "Propagation issues on Service Perimeter.",

		".*Error when reading or editing AccessLevelCondition*": "Propagation issues on Access Level.",

		".*Error 400: The email address 'service-*@*.iam.gserviceaccount.com' is invalid or non-existent*": "Service Agent propagation.",

		".*dial tcp: lookup *.nip.io on *: server misbehaving*": "VM Gitlab issues.",

		".Error 400: Invalid Directional Policies set in Perimeter*": "VPC-SC propagation issues",
	}
)

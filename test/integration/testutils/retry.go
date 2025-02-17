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

		// Request had invalid authentication credentials.*
		".*Request had invalid authentication credentials.*": "Request had invalid authentication credentials.",

		// Error waiting for Creating Repository: Error code 13, message: Internal error encountered.
		".Internal error encountered*": "Internal error encountered",

		// generic::permission_denied: Request is prohibited by organization's policy.
		".*Request is prohibited by organization's policy*.": "VPC-SC propagation.",
	}
)

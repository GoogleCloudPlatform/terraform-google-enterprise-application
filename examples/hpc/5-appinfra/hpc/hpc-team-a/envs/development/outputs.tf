/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

output "ai_training_data_bucket_name" {
  description = "AI Training Example Bucket Name"
  value       = module.provision-ai-training-infra.ai_training_data_bucket_name
}

output "image_url" {
  description = "AI Image URL"
  value       = module.provision-ai-training-infra.image_url
}

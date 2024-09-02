/**
 * Copyright 2024 Google LLC
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

apps = {
  "cymbal-bank-1" : {
    "ip_address_names" : [
      "frontend-ip",
    ]
    "certificates" : {
      "frontend-cb1-com" : ["frontend.cb1.com"]
    },
    "acronyms" = "cb1",
  },
  "cymbal-bank-2" : {
    "ip_address_names" : [
      "frontend-ip",
    ]
    "certificates" : {
      "frontend-cb2-com" : ["frontend.cb2.com"]
    },
    "acronyms" = "cb2",
  }
}

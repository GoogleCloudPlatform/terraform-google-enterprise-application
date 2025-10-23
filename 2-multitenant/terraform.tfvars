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
  "cymbal-bank" : {
    "ip_address_names" : [
      "frontend-ip",
    ]
    "certificates" : {
      "frontend-example-com" : ["frontend.example.com"]
    }
    "acronym" = "cb",
  }
  "cymbal-shop" : {
    "ip_address_names" : [
      "cymbal-shop-frontend-ip",
    ]
    "certificates" : {
      "cymbal-shop-frontend-example-com" : ["cymbal-shop.frontend.example.com"]
    }
    "acronym" = "cs",
  }
  "default-example" : {
    "acronym" = "de",
  }
  "hpc" : {
    "acronym" = "hpc",
  }
  "agent" : {
    "acronym" = "agt",
  }
}

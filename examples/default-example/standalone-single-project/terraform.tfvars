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

# project_id = "<YOUR-PROJECT-ID>"
# workerpool_network_id = "<YOUR-NETWORK-ID>"
# subnetwork_self_link = "<YOUR-CLUSTER-SUBNETWORK-SELF-LINK>"
# teams = {
#   "namespace" = "your-group@yourdomain.com",
# }
# service_perimeter_name = "<YOUR-SERVICE-PERIMETER-NAME>"
# service_perimeter_mode = "DRY_RUN"

cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
    "eab-default-example-hello-world" = {
      repository_name = "eab-default-example-hello-world"
      repository_url  = "https://gitlab.example.com/root/eab-default-example-hello-world.git"
    }
  }
    gitlab_authorizer_credential_secret_id      = "projects/489524140334/secrets/gitlab-pat-from-vm"
  gitlab_read_authorizer_credential_secret_id = "projects/489524140334/secrets/gitlab-pat-from-vm"
  gitlab_webhook_secret_id                    = "projects/eab-gitlab-mia9/secrets/gitlab-webhook"
  secret_project_id                           = "eab-gitlab-mia9"

  # If you are using a self-hosted instance, you may change the URL below accordingly
  gitlab_enterprise_host_uri = "https://gitlab.example.com"
  # Format is projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE
  gitlab_enterprise_service_directory = "projects/eab-gitlab-mia9/locations/us-central1/namespaces/gitlab-namespace/services/gitlab"
  # .pem string
  gitlab_enterprise_ca_certificate = <<EOF
-----BEGIN CERTIFICATE-----
MIIGKTCCBBGgAwIBAgIUTRzdv6Ac/CnREm2cy7z9eUGrmWMwDQYJKoZIhvcNAQEL
BQAwgYQxCzAJBgNVBAYTAlhYMRIwEAYDVQQIDAlTdGF0ZU5hbWUxETAPBgNVBAcM
CENpdHlOYW1lMRQwEgYDVQQKDAtDb21wYW55TmFtZTEbMBkGA1UECwwSQ29tcGFu
eVNlY3Rpb25OYW1lMRswGQYDVQQDDBJnaXRsYWIuZXhhbXBsZS5jb20wHhcNMjYw
NzEzMTI0OTI4WhcNMzYwNzEwMTI0OTI4WjCBhDELMAkGA1UEBhMCWFgxEjAQBgNV
BAgMCVN0YXRlTmFtZTERMA8GA1UEBwwIQ2l0eU5hbWUxFDASBgNVBAoMC0NvbXBh
bnlOYW1lMRswGQYDVQQLDBJDb21wYW55U2VjdGlvbk5hbWUxGzAZBgNVBAMMEmdp
dGxhYi5leGFtcGxlLmNvbTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
AK06h+Apjzh3WeSTP78hDU85pdyG4UViMbsac7jN1QiVeDJVTaPIkvKhg0sAwjiw
DzxNsTfrTFkXS0Q5IQ3E4QNMVxQiYpvEF2sg84/GkieIxv8au0dDz6nOiZUbk/zD
jbx3330sWW587MIHdzMaHMcvinxpPQUUgugfySUzqx47CzwsZaAjnUWs/HorU6ea
/DNbkkAto6maqjDME3KEkrT/akGx2w0MYMurvw1XKwawhINzPIu7NvjN5ElTsC03
fznX5JKnT+3ByWjRLgIqEXdKwmTSJ4miCqQLfCDV/yHyYG0SIRSReaB3hTWT+v+g
581cCcqS1dhCRPT2vEpLUegDwA6jHYcqZGBOqXfXItWdgOPb79KLuavdXvrjIBXt
21f378S7GCbP2A8IYDeXXj9jUVdvxzzmUftqlhtHKyxQWj0mauDJNONNxA0J9WxS
OkKn/Dm2/d+jhyIqGqCNihtm6Mg02qoD/zd78njNFYOpL0ktQdlPSTCM/ekUY8bh
2U2jbT1bZjYt6hAINAQvdlb6GEKL8Aygy9bPloZXwlMcnEMFM7MwAZ0Y6OT6uycw
W1X8vah4nZEZ2hNxf42jWrE2NTLsJ9PJDkr+GumCjv9+Fut8uboesMqz4gDxFkgj
48vPAxM6vBC9iVU2bkWndx4ib0FO4co5oHlBSJfM0DKdAgMBAAGjgZAwgY0wHQYD
VR0OBBYEFIYP4GzdmzBJlF6rYZflhsDGKGLYMB8GA1UdIwQYMBaAFIYP4GzdmzBJ
lF6rYZflhsDGKGLYMA8GA1UdEwEB/wQFMAMBAf8wOgYDVR0RBDMwMYISZ2l0bGFi
LmV4YW1wbGUuY29thwQiCiXsghUzNC4xMC4zNy4yMzYuc3NsaXAuaW8wDQYJKoZI
hvcNAQELBQADggIBAAISqR5+y+1D/EvsL+MVloY0CejBV0qS9gIExZXehVNwuS9C
60F+LE1OXDoLI4rZCkOFmeZjBnf8XUMra4benWipNgNIXkBWFIrhaqZcGmcCgF4e
NVCBZlRQPLMu3Nlf45K92NSqvSqHOb/ofhYEj8ph1WtuVNxBs4KSCshPoAVl7U9I
vXz9dGtdjNW2bVHxjd9UU7g5yzpnA7UEtILCp0P/aGJoAJO/FIgrDNpcamxpzG0D
LfNmZ5QRyOaarXC7vcE3UEZerzXohCJgwHx/VBbhfBztlVXqor7xn/EjK1AZOHB4
KYyb3ZhFlIxoCpCg8BlLfruiaeNJCdHYVkFlz7Ulhl0lIXHeDTSK55KbAzYYB1FX
QSt7M31rsFwaNMW3fc+s89+V/MgED2ECqv1WCrazX3bEjX13e8YqH6d7iOZelKed
FEKHLY6ccP3l+LXrXMmK5a5qUzdMgSHPyExZxhHHbZ212nsFP/9HqkjpYzlUqzzO
QZ0MlNOSK6Vxwmi4r6UoDQK/YEhCka50hH+JxjOdTKJBdn9T8PaYcFg/rK5Kx/je
JJM7NZcQv2NsvLybWocQ2UlO1ddl+4ejebKXqoKb65VMUU0+QtS8MNzWrJAqwApt
zyVNeuAIEriMQwQgyEfGUDa7VRwuoZB9eRRbt9IcBpAcm3nwdqxlxmgvPFNu
-----END CERTIFICATE-----
EOF
}

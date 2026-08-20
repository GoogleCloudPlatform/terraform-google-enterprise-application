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

# 5-appinfra

# app_01
locals {

  cluster_membership_ids = { (local.env) : { "cluster_membership_ids" : module.multitenant_infra.cluster_membership_ids } }

  sa_cb = [for cicd in module.cicd : "serviceAccount:${cicd.cloudbuild_service_account}"]

  cicd_apps = {
    "contacts" = {
      application_name = "cymbal-bank"
      service_name     = "contacts"
      team_name        = "accounts"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-accounts-contacts" = {
            repository_name = "eab-cymbal-bank-accounts-contacts"
            repository_url  = "https://gitlab.example.com/root/eab-cymbal-bank-accounts-contacts.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_read_authorizer_credential_secret_id = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_webhook_secret_id                    = "projects/eab-gitlab-mxx6/secrets/gitlab-webhook"
        gitlab_enterprise_host_uri                  = "https://gitlab.example.com"
        # Format is projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE
        gitlab_enterprise_service_directory = "projects/eab-gitlab-mxx6/locations/us-central1/namespaces/gitlab-namespace/services/gitlab"
        # .pem string
        gitlab_enterprise_ca_certificate = <<EOF
-----BEGIN CERTIFICATE-----
MIIGKzCCBBOgAwIBAgIUZj0HSpEkG7GEkALOMnhu7jvATvswDQYJKoZIhvcNAQEL
BQAwgYQxCzAJBgNVBAYTAlhYMRIwEAYDVQQIDAlTdGF0ZU5hbWUxETAPBgNVBAcM
CENpdHlOYW1lMRQwEgYDVQQKDAtDb21wYW55TmFtZTEbMBkGA1UECwwSQ29tcGFu
eVNlY3Rpb25OYW1lMRswGQYDVQQDDBJnaXRsYWIuZXhhbXBsZS5jb20wHhcNMjYw
ODIwMTgxOTA4WhcNMzYwODE3MTgxOTA4WjCBhDELMAkGA1UEBhMCWFgxEjAQBgNV
BAgMCVN0YXRlTmFtZTERMA8GA1UEBwwIQ2l0eU5hbWUxFDASBgNVBAoMC0NvbXBh
bnlOYW1lMRswGQYDVQQLDBJDb21wYW55U2VjdGlvbk5hbWUxGzAZBgNVBAMMEmdp
dGxhYi5leGFtcGxlLmNvbTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
ALo6XPKoQoZTObrusVBuzPa3fbdFPIU3+V3a9NZMP+6r+kzMAq8lPpRm3gRetOqj
dBQAgGPdXuO/FhRm8YNLRuwWCI69ZjvI0w4BLiPVuWLS+NWFQPbggs7uM5RWmf0A
LYV/Og8wbSELqGcb46l31pSaAnBW3oZqM/2+OjxERaOpbXq23P5Py9suR61C9aot
SmlDkkPkvT/0kgISUOObgbMVbmRcs7yP5DRuyyZih2ftxlWXsaaNqvcIMIwyReq4
AlVtDmnovs5c+PGXXTcuuv5fVSFTRwdOPE4SDUSrArQHFFrX/K66LZB9aqXk7M4v
u3cChTDtEC+3D5IbZ2tC7j3FtQ9rfv+U12R3BvWhJkvtG4db5AVy978w6ylAoxHc
SSy2el9Cu21QX/vndkm5pSZfhUE+x2/ysqlTCEUNtGkYjfedA60q8Sytlu0ioRMy
PstE4pNP8Z0arV1HPMBMJcsyogeCV1Cpykcn/prLiuRs5VYNKanDIcq9cn6PZj29
EcvQrRV3mluxZMEjovHiedt1kxQpbWr87b1sEN6hNJl/224UTD5po4kvFiM/Q8mO
JIzjwFY3GWdtUPbH00H8FVnKyWdSL61AXuLV8IkKagoJGJxTG5zz12fiigsByCw9
7bV8QtoRzvuGrDuq4l57znjlulvagsnGhjlRdLacNxwBAgMBAAGjgZIwgY8wHQYD
VR0OBBYEFCAYgN5cahZVOn1oeO1XLhHCib6YMB8GA1UdIwQYMBaAFCAYgN5cahZV
On1oeO1XLhHCib6YMA8GA1UdEwEB/wQFMAMBAf8wPAYDVR0RBDUwM4ISZ2l0bGFi
LmV4YW1wbGUuY29thwSIcXRIghcxMzYuMTEzLjExNi43Mi5zc2xpcC5pbzANBgkq
hkiG9w0BAQsFAAOCAgEAe347cGbyuWGehUfPGlgzh9WxTyxsdsXWvT09bdQRZDcr
8mY40IFU4zHm+vKOc8e54aezszIx1usMJbyyBl/omeiS/XyLhnDjqRBX/l8xUleo
5rPDNiz59fxZU7bdo8jntf7WpR75Zj1CrQTaRtD2FppJMxRb9VMfagHL6U9HIFPr
+tBF42VgT0OgfJTqjbFxIqG2nSOi9DKS2g7E9tSMwWlkw0vtJTqfQyVBgAqxZIsQ
15SUI3oDFlqivfkbbiX50YgvXiG9FS7OuCIs5RM6Y+QpXNJHb+pakRgRNtK+ScVm
UHTXZFB70jWY1k6wMXsNXw3dvibvGGzkq0otf0vlmQoL7sjH2I6cfAMioGi9Y2s7
POLN6nY1Vh50zA8UkcewTKR/EHtqnwdg2kktyG9ZrOh4U03mpnxNrZJA08Qz9ghl
7YlseF9NgZp2PMVMCiYMoTJZ9Ye0x/FNjhcbCGYoCBTvAZfDQsKybEm6XFUIr+Tm
I1Pu71u7NipHNwmYsboXwoubO9YYCicg+Gqhx63KNInA4QqQo4PZblfmgFwOT9Uq
sUb/t1q6x7rsQaFlIQ+vPcsRyiZwKBgyN9EBY8DE2B9M9XKAMOJkNgk74Z2TIZBs
jpsBz4xvORNhw9FOCiN3+sCR4wngYGsgUENYkD1rOp30B9LkyfKFC02f5cW0IOQ=
-----END CERTIFICATE-----
EOF
      }
    },
    "userservice" = {
      application_name = "cymbal-bank"
      service_name     = "userservice"
      team_name        = "accounts"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-accounts-userservice" = {
            repository_name = "eab-cymbal-bank-accounts-userservice"
            repository_url  = "https://gitlab.example.com/root/eab-cymbal-bank-accounts-userservice.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_read_authorizer_credential_secret_id = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_webhook_secret_id                    = "projects/eab-gitlab-mxx6/secrets/gitlab-webhook"
        gitlab_enterprise_host_uri                  = "https://gitlab.example.com"
        # Format is projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE
        gitlab_enterprise_service_directory = "projects/eab-gitlab-mxx6/locations/us-central1/namespaces/gitlab-namespace/services/gitlab"
        # .pem string
        gitlab_enterprise_ca_certificate = <<EOF
-----BEGIN CERTIFICATE-----
MIIGKzCCBBOgAwIBAgIUZj0HSpEkG7GEkALOMnhu7jvATvswDQYJKoZIhvcNAQEL
BQAwgYQxCzAJBgNVBAYTAlhYMRIwEAYDVQQIDAlTdGF0ZU5hbWUxETAPBgNVBAcM
CENpdHlOYW1lMRQwEgYDVQQKDAtDb21wYW55TmFtZTEbMBkGA1UECwwSQ29tcGFu
eVNlY3Rpb25OYW1lMRswGQYDVQQDDBJnaXRsYWIuZXhhbXBsZS5jb20wHhcNMjYw
ODIwMTgxOTA4WhcNMzYwODE3MTgxOTA4WjCBhDELMAkGA1UEBhMCWFgxEjAQBgNV
BAgMCVN0YXRlTmFtZTERMA8GA1UEBwwIQ2l0eU5hbWUxFDASBgNVBAoMC0NvbXBh
bnlOYW1lMRswGQYDVQQLDBJDb21wYW55U2VjdGlvbk5hbWUxGzAZBgNVBAMMEmdp
dGxhYi5leGFtcGxlLmNvbTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
ALo6XPKoQoZTObrusVBuzPa3fbdFPIU3+V3a9NZMP+6r+kzMAq8lPpRm3gRetOqj
dBQAgGPdXuO/FhRm8YNLRuwWCI69ZjvI0w4BLiPVuWLS+NWFQPbggs7uM5RWmf0A
LYV/Og8wbSELqGcb46l31pSaAnBW3oZqM/2+OjxERaOpbXq23P5Py9suR61C9aot
SmlDkkPkvT/0kgISUOObgbMVbmRcs7yP5DRuyyZih2ftxlWXsaaNqvcIMIwyReq4
AlVtDmnovs5c+PGXXTcuuv5fVSFTRwdOPE4SDUSrArQHFFrX/K66LZB9aqXk7M4v
u3cChTDtEC+3D5IbZ2tC7j3FtQ9rfv+U12R3BvWhJkvtG4db5AVy978w6ylAoxHc
SSy2el9Cu21QX/vndkm5pSZfhUE+x2/ysqlTCEUNtGkYjfedA60q8Sytlu0ioRMy
PstE4pNP8Z0arV1HPMBMJcsyogeCV1Cpykcn/prLiuRs5VYNKanDIcq9cn6PZj29
EcvQrRV3mluxZMEjovHiedt1kxQpbWr87b1sEN6hNJl/224UTD5po4kvFiM/Q8mO
JIzjwFY3GWdtUPbH00H8FVnKyWdSL61AXuLV8IkKagoJGJxTG5zz12fiigsByCw9
7bV8QtoRzvuGrDuq4l57znjlulvagsnGhjlRdLacNxwBAgMBAAGjgZIwgY8wHQYD
VR0OBBYEFCAYgN5cahZVOn1oeO1XLhHCib6YMB8GA1UdIwQYMBaAFCAYgN5cahZV
On1oeO1XLhHCib6YMA8GA1UdEwEB/wQFMAMBAf8wPAYDVR0RBDUwM4ISZ2l0bGFi
LmV4YW1wbGUuY29thwSIcXRIghcxMzYuMTEzLjExNi43Mi5zc2xpcC5pbzANBgkq
hkiG9w0BAQsFAAOCAgEAe347cGbyuWGehUfPGlgzh9WxTyxsdsXWvT09bdQRZDcr
8mY40IFU4zHm+vKOc8e54aezszIx1usMJbyyBl/omeiS/XyLhnDjqRBX/l8xUleo
5rPDNiz59fxZU7bdo8jntf7WpR75Zj1CrQTaRtD2FppJMxRb9VMfagHL6U9HIFPr
+tBF42VgT0OgfJTqjbFxIqG2nSOi9DKS2g7E9tSMwWlkw0vtJTqfQyVBgAqxZIsQ
15SUI3oDFlqivfkbbiX50YgvXiG9FS7OuCIs5RM6Y+QpXNJHb+pakRgRNtK+ScVm
UHTXZFB70jWY1k6wMXsNXw3dvibvGGzkq0otf0vlmQoL7sjH2I6cfAMioGi9Y2s7
POLN6nY1Vh50zA8UkcewTKR/EHtqnwdg2kktyG9ZrOh4U03mpnxNrZJA08Qz9ghl
7YlseF9NgZp2PMVMCiYMoTJZ9Ye0x/FNjhcbCGYoCBTvAZfDQsKybEm6XFUIr+Tm
I1Pu71u7NipHNwmYsboXwoubO9YYCicg+Gqhx63KNInA4QqQo4PZblfmgFwOT9Uq
sUb/t1q6x7rsQaFlIQ+vPcsRyiZwKBgyN9EBY8DE2B9M9XKAMOJkNgk74Z2TIZBs
jpsBz4xvORNhw9FOCiN3+sCR4wngYGsgUENYkD1rOp30B9LkyfKFC02f5cW0IOQ=
-----END CERTIFICATE-----
EOF
      }
    },
    "frontend" = {
      application_name = "cymbal-bank"
      service_name     = "frontend"
      team_name        = "frontend"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-frontend" = {
            repository_name = "eab-cymbal-bank-frontend"
            repository_url  = "https://gitlab.example.com/root/eab-cymbal-bank-frontend.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_read_authorizer_credential_secret_id = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_webhook_secret_id                    = "projects/eab-gitlab-mxx6/secrets/gitlab-webhook"
        gitlab_enterprise_host_uri                  = "https://gitlab.example.com"
        # Format is projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE
        gitlab_enterprise_service_directory = "projects/eab-gitlab-mxx6/locations/us-central1/namespaces/gitlab-namespace/services/gitlab"
        # .pem string
        gitlab_enterprise_ca_certificate = <<EOF
-----BEGIN CERTIFICATE-----
MIIGKzCCBBOgAwIBAgIUZj0HSpEkG7GEkALOMnhu7jvATvswDQYJKoZIhvcNAQEL
BQAwgYQxCzAJBgNVBAYTAlhYMRIwEAYDVQQIDAlTdGF0ZU5hbWUxETAPBgNVBAcM
CENpdHlOYW1lMRQwEgYDVQQKDAtDb21wYW55TmFtZTEbMBkGA1UECwwSQ29tcGFu
eVNlY3Rpb25OYW1lMRswGQYDVQQDDBJnaXRsYWIuZXhhbXBsZS5jb20wHhcNMjYw
ODIwMTgxOTA4WhcNMzYwODE3MTgxOTA4WjCBhDELMAkGA1UEBhMCWFgxEjAQBgNV
BAgMCVN0YXRlTmFtZTERMA8GA1UEBwwIQ2l0eU5hbWUxFDASBgNVBAoMC0NvbXBh
bnlOYW1lMRswGQYDVQQLDBJDb21wYW55U2VjdGlvbk5hbWUxGzAZBgNVBAMMEmdp
dGxhYi5leGFtcGxlLmNvbTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
ALo6XPKoQoZTObrusVBuzPa3fbdFPIU3+V3a9NZMP+6r+kzMAq8lPpRm3gRetOqj
dBQAgGPdXuO/FhRm8YNLRuwWCI69ZjvI0w4BLiPVuWLS+NWFQPbggs7uM5RWmf0A
LYV/Og8wbSELqGcb46l31pSaAnBW3oZqM/2+OjxERaOpbXq23P5Py9suR61C9aot
SmlDkkPkvT/0kgISUOObgbMVbmRcs7yP5DRuyyZih2ftxlWXsaaNqvcIMIwyReq4
AlVtDmnovs5c+PGXXTcuuv5fVSFTRwdOPE4SDUSrArQHFFrX/K66LZB9aqXk7M4v
u3cChTDtEC+3D5IbZ2tC7j3FtQ9rfv+U12R3BvWhJkvtG4db5AVy978w6ylAoxHc
SSy2el9Cu21QX/vndkm5pSZfhUE+x2/ysqlTCEUNtGkYjfedA60q8Sytlu0ioRMy
PstE4pNP8Z0arV1HPMBMJcsyogeCV1Cpykcn/prLiuRs5VYNKanDIcq9cn6PZj29
EcvQrRV3mluxZMEjovHiedt1kxQpbWr87b1sEN6hNJl/224UTD5po4kvFiM/Q8mO
JIzjwFY3GWdtUPbH00H8FVnKyWdSL61AXuLV8IkKagoJGJxTG5zz12fiigsByCw9
7bV8QtoRzvuGrDuq4l57znjlulvagsnGhjlRdLacNxwBAgMBAAGjgZIwgY8wHQYD
VR0OBBYEFCAYgN5cahZVOn1oeO1XLhHCib6YMB8GA1UdIwQYMBaAFCAYgN5cahZV
On1oeO1XLhHCib6YMA8GA1UdEwEB/wQFMAMBAf8wPAYDVR0RBDUwM4ISZ2l0bGFi
LmV4YW1wbGUuY29thwSIcXRIghcxMzYuMTEzLjExNi43Mi5zc2xpcC5pbzANBgkq
hkiG9w0BAQsFAAOCAgEAe347cGbyuWGehUfPGlgzh9WxTyxsdsXWvT09bdQRZDcr
8mY40IFU4zHm+vKOc8e54aezszIx1usMJbyyBl/omeiS/XyLhnDjqRBX/l8xUleo
5rPDNiz59fxZU7bdo8jntf7WpR75Zj1CrQTaRtD2FppJMxRb9VMfagHL6U9HIFPr
+tBF42VgT0OgfJTqjbFxIqG2nSOi9DKS2g7E9tSMwWlkw0vtJTqfQyVBgAqxZIsQ
15SUI3oDFlqivfkbbiX50YgvXiG9FS7OuCIs5RM6Y+QpXNJHb+pakRgRNtK+ScVm
UHTXZFB70jWY1k6wMXsNXw3dvibvGGzkq0otf0vlmQoL7sjH2I6cfAMioGi9Y2s7
POLN6nY1Vh50zA8UkcewTKR/EHtqnwdg2kktyG9ZrOh4U03mpnxNrZJA08Qz9ghl
7YlseF9NgZp2PMVMCiYMoTJZ9Ye0x/FNjhcbCGYoCBTvAZfDQsKybEm6XFUIr+Tm
I1Pu71u7NipHNwmYsboXwoubO9YYCicg+Gqhx63KNInA4QqQo4PZblfmgFwOT9Uq
sUb/t1q6x7rsQaFlIQ+vPcsRyiZwKBgyN9EBY8DE2B9M9XKAMOJkNgk74Z2TIZBs
jpsBz4xvORNhw9FOCiN3+sCR4wngYGsgUENYkD1rOp30B9LkyfKFC02f5cW0IOQ=
-----END CERTIFICATE-----
EOF
      }
    },
    "balancereader" = {
      application_name = "cymbal-bank"
      service_name     = "balancereader"
      team_name        = "ledger"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-ledger-balancereader" = {
            repository_name = "eab-cymbal-bank-ledger-balancereader"
            repository_url  = "https://gitlab.example.com/root/eab-cymbal-bank-ledger-balancereader.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_read_authorizer_credential_secret_id = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_webhook_secret_id                    = "projects/eab-gitlab-mxx6/secrets/gitlab-webhook"
        gitlab_enterprise_host_uri                  = "https://gitlab.example.com"
        # Format is projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE
        gitlab_enterprise_service_directory = "projects/eab-gitlab-mxx6/locations/us-central1/namespaces/gitlab-namespace/services/gitlab"
        # .pem string
        gitlab_enterprise_ca_certificate = <<EOF
-----BEGIN CERTIFICATE-----
MIIGKzCCBBOgAwIBAgIUZj0HSpEkG7GEkALOMnhu7jvATvswDQYJKoZIhvcNAQEL
BQAwgYQxCzAJBgNVBAYTAlhYMRIwEAYDVQQIDAlTdGF0ZU5hbWUxETAPBgNVBAcM
CENpdHlOYW1lMRQwEgYDVQQKDAtDb21wYW55TmFtZTEbMBkGA1UECwwSQ29tcGFu
eVNlY3Rpb25OYW1lMRswGQYDVQQDDBJnaXRsYWIuZXhhbXBsZS5jb20wHhcNMjYw
ODIwMTgxOTA4WhcNMzYwODE3MTgxOTA4WjCBhDELMAkGA1UEBhMCWFgxEjAQBgNV
BAgMCVN0YXRlTmFtZTERMA8GA1UEBwwIQ2l0eU5hbWUxFDASBgNVBAoMC0NvbXBh
bnlOYW1lMRswGQYDVQQLDBJDb21wYW55U2VjdGlvbk5hbWUxGzAZBgNVBAMMEmdp
dGxhYi5leGFtcGxlLmNvbTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
ALo6XPKoQoZTObrusVBuzPa3fbdFPIU3+V3a9NZMP+6r+kzMAq8lPpRm3gRetOqj
dBQAgGPdXuO/FhRm8YNLRuwWCI69ZjvI0w4BLiPVuWLS+NWFQPbggs7uM5RWmf0A
LYV/Og8wbSELqGcb46l31pSaAnBW3oZqM/2+OjxERaOpbXq23P5Py9suR61C9aot
SmlDkkPkvT/0kgISUOObgbMVbmRcs7yP5DRuyyZih2ftxlWXsaaNqvcIMIwyReq4
AlVtDmnovs5c+PGXXTcuuv5fVSFTRwdOPE4SDUSrArQHFFrX/K66LZB9aqXk7M4v
u3cChTDtEC+3D5IbZ2tC7j3FtQ9rfv+U12R3BvWhJkvtG4db5AVy978w6ylAoxHc
SSy2el9Cu21QX/vndkm5pSZfhUE+x2/ysqlTCEUNtGkYjfedA60q8Sytlu0ioRMy
PstE4pNP8Z0arV1HPMBMJcsyogeCV1Cpykcn/prLiuRs5VYNKanDIcq9cn6PZj29
EcvQrRV3mluxZMEjovHiedt1kxQpbWr87b1sEN6hNJl/224UTD5po4kvFiM/Q8mO
JIzjwFY3GWdtUPbH00H8FVnKyWdSL61AXuLV8IkKagoJGJxTG5zz12fiigsByCw9
7bV8QtoRzvuGrDuq4l57znjlulvagsnGhjlRdLacNxwBAgMBAAGjgZIwgY8wHQYD
VR0OBBYEFCAYgN5cahZVOn1oeO1XLhHCib6YMB8GA1UdIwQYMBaAFCAYgN5cahZV
On1oeO1XLhHCib6YMA8GA1UdEwEB/wQFMAMBAf8wPAYDVR0RBDUwM4ISZ2l0bGFi
LmV4YW1wbGUuY29thwSIcXRIghcxMzYuMTEzLjExNi43Mi5zc2xpcC5pbzANBgkq
hkiG9w0BAQsFAAOCAgEAe347cGbyuWGehUfPGlgzh9WxTyxsdsXWvT09bdQRZDcr
8mY40IFU4zHm+vKOc8e54aezszIx1usMJbyyBl/omeiS/XyLhnDjqRBX/l8xUleo
5rPDNiz59fxZU7bdo8jntf7WpR75Zj1CrQTaRtD2FppJMxRb9VMfagHL6U9HIFPr
+tBF42VgT0OgfJTqjbFxIqG2nSOi9DKS2g7E9tSMwWlkw0vtJTqfQyVBgAqxZIsQ
15SUI3oDFlqivfkbbiX50YgvXiG9FS7OuCIs5RM6Y+QpXNJHb+pakRgRNtK+ScVm
UHTXZFB70jWY1k6wMXsNXw3dvibvGGzkq0otf0vlmQoL7sjH2I6cfAMioGi9Y2s7
POLN6nY1Vh50zA8UkcewTKR/EHtqnwdg2kktyG9ZrOh4U03mpnxNrZJA08Qz9ghl
7YlseF9NgZp2PMVMCiYMoTJZ9Ye0x/FNjhcbCGYoCBTvAZfDQsKybEm6XFUIr+Tm
I1Pu71u7NipHNwmYsboXwoubO9YYCicg+Gqhx63KNInA4QqQo4PZblfmgFwOT9Uq
sUb/t1q6x7rsQaFlIQ+vPcsRyiZwKBgyN9EBY8DE2B9M9XKAMOJkNgk74Z2TIZBs
jpsBz4xvORNhw9FOCiN3+sCR4wngYGsgUENYkD1rOp30B9LkyfKFC02f5cW0IOQ=
-----END CERTIFICATE-----
EOF
      }
    },
    "ledgerwriter" = {
      application_name = "cymbal-bank"
      service_name     = "ledgerwriter"
      team_name        = "ledger"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-ledger-ledgerwriter" = {
            repository_name = "eab-cymbal-bank-ledger-ledgerwriter"
            repository_url  = "https://gitlab.example.com/root/eab-cymbal-bank-ledger-ledgerwriter.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_read_authorizer_credential_secret_id = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_webhook_secret_id                    = "projects/eab-gitlab-mxx6/secrets/gitlab-webhook"
        gitlab_enterprise_host_uri                  = "https://gitlab.example.com"
        # Format is projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE
        gitlab_enterprise_service_directory = "projects/eab-gitlab-mxx6/locations/us-central1/namespaces/gitlab-namespace/services/gitlab"
        # .pem string
        gitlab_enterprise_ca_certificate = <<EOF
-----BEGIN CERTIFICATE-----
MIIGKzCCBBOgAwIBAgIUZj0HSpEkG7GEkALOMnhu7jvATvswDQYJKoZIhvcNAQEL
BQAwgYQxCzAJBgNVBAYTAlhYMRIwEAYDVQQIDAlTdGF0ZU5hbWUxETAPBgNVBAcM
CENpdHlOYW1lMRQwEgYDVQQKDAtDb21wYW55TmFtZTEbMBkGA1UECwwSQ29tcGFu
eVNlY3Rpb25OYW1lMRswGQYDVQQDDBJnaXRsYWIuZXhhbXBsZS5jb20wHhcNMjYw
ODIwMTgxOTA4WhcNMzYwODE3MTgxOTA4WjCBhDELMAkGA1UEBhMCWFgxEjAQBgNV
BAgMCVN0YXRlTmFtZTERMA8GA1UEBwwIQ2l0eU5hbWUxFDASBgNVBAoMC0NvbXBh
bnlOYW1lMRswGQYDVQQLDBJDb21wYW55U2VjdGlvbk5hbWUxGzAZBgNVBAMMEmdp
dGxhYi5leGFtcGxlLmNvbTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
ALo6XPKoQoZTObrusVBuzPa3fbdFPIU3+V3a9NZMP+6r+kzMAq8lPpRm3gRetOqj
dBQAgGPdXuO/FhRm8YNLRuwWCI69ZjvI0w4BLiPVuWLS+NWFQPbggs7uM5RWmf0A
LYV/Og8wbSELqGcb46l31pSaAnBW3oZqM/2+OjxERaOpbXq23P5Py9suR61C9aot
SmlDkkPkvT/0kgISUOObgbMVbmRcs7yP5DRuyyZih2ftxlWXsaaNqvcIMIwyReq4
AlVtDmnovs5c+PGXXTcuuv5fVSFTRwdOPE4SDUSrArQHFFrX/K66LZB9aqXk7M4v
u3cChTDtEC+3D5IbZ2tC7j3FtQ9rfv+U12R3BvWhJkvtG4db5AVy978w6ylAoxHc
SSy2el9Cu21QX/vndkm5pSZfhUE+x2/ysqlTCEUNtGkYjfedA60q8Sytlu0ioRMy
PstE4pNP8Z0arV1HPMBMJcsyogeCV1Cpykcn/prLiuRs5VYNKanDIcq9cn6PZj29
EcvQrRV3mluxZMEjovHiedt1kxQpbWr87b1sEN6hNJl/224UTD5po4kvFiM/Q8mO
JIzjwFY3GWdtUPbH00H8FVnKyWdSL61AXuLV8IkKagoJGJxTG5zz12fiigsByCw9
7bV8QtoRzvuGrDuq4l57znjlulvagsnGhjlRdLacNxwBAgMBAAGjgZIwgY8wHQYD
VR0OBBYEFCAYgN5cahZVOn1oeO1XLhHCib6YMB8GA1UdIwQYMBaAFCAYgN5cahZV
On1oeO1XLhHCib6YMA8GA1UdEwEB/wQFMAMBAf8wPAYDVR0RBDUwM4ISZ2l0bGFi
LmV4YW1wbGUuY29thwSIcXRIghcxMzYuMTEzLjExNi43Mi5zc2xpcC5pbzANBgkq
hkiG9w0BAQsFAAOCAgEAe347cGbyuWGehUfPGlgzh9WxTyxsdsXWvT09bdQRZDcr
8mY40IFU4zHm+vKOc8e54aezszIx1usMJbyyBl/omeiS/XyLhnDjqRBX/l8xUleo
5rPDNiz59fxZU7bdo8jntf7WpR75Zj1CrQTaRtD2FppJMxRb9VMfagHL6U9HIFPr
+tBF42VgT0OgfJTqjbFxIqG2nSOi9DKS2g7E9tSMwWlkw0vtJTqfQyVBgAqxZIsQ
15SUI3oDFlqivfkbbiX50YgvXiG9FS7OuCIs5RM6Y+QpXNJHb+pakRgRNtK+ScVm
UHTXZFB70jWY1k6wMXsNXw3dvibvGGzkq0otf0vlmQoL7sjH2I6cfAMioGi9Y2s7
POLN6nY1Vh50zA8UkcewTKR/EHtqnwdg2kktyG9ZrOh4U03mpnxNrZJA08Qz9ghl
7YlseF9NgZp2PMVMCiYMoTJZ9Ye0x/FNjhcbCGYoCBTvAZfDQsKybEm6XFUIr+Tm
I1Pu71u7NipHNwmYsboXwoubO9YYCicg+Gqhx63KNInA4QqQo4PZblfmgFwOT9Uq
sUb/t1q6x7rsQaFlIQ+vPcsRyiZwKBgyN9EBY8DE2B9M9XKAMOJkNgk74Z2TIZBs
jpsBz4xvORNhw9FOCiN3+sCR4wngYGsgUENYkD1rOp30B9LkyfKFC02f5cW0IOQ=
-----END CERTIFICATE-----
EOF
      }
    },
    "transactionhistory" = {
      application_name = "cymbal-bank"
      service_name     = "transactionhistory"
      team_name        = "ledger"
      repo_branch      = "main"
      cloudbuildv2_repository_config = {
        repo_type = "GITLABv2"
        repositories = {
          "eab-cymbal-bank-ledger-transactionhistory" = {
            repository_name = "eab-cymbal-bank-ledger-transactionhistory"
            repository_url  = "https://gitlab.example.com/root/eab-cymbal-bank-ledger-transactionhistory.git"
          }
        }
        gitlab_authorizer_credential_secret_id      = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_read_authorizer_credential_secret_id = "projects/879050112661/secrets/gitlab-pat-from-vm"
        gitlab_webhook_secret_id                    = "projects/eab-gitlab-mxx6/secrets/gitlab-webhook"
        gitlab_enterprise_host_uri                  = "https://gitlab.example.com"
        # Format is projects/PROJECT/locations/LOCATION/namespaces/NAMESPACE/services/SERVICE
        gitlab_enterprise_service_directory = "projects/eab-gitlab-mxx6/locations/us-central1/namespaces/gitlab-namespace/services/gitlab"
        # .pem string
        gitlab_enterprise_ca_certificate = <<EOF
-----BEGIN CERTIFICATE-----
MIIGKzCCBBOgAwIBAgIUZj0HSpEkG7GEkALOMnhu7jvATvswDQYJKoZIhvcNAQEL
BQAwgYQxCzAJBgNVBAYTAlhYMRIwEAYDVQQIDAlTdGF0ZU5hbWUxETAPBgNVBAcM
CENpdHlOYW1lMRQwEgYDVQQKDAtDb21wYW55TmFtZTEbMBkGA1UECwwSQ29tcGFu
eVNlY3Rpb25OYW1lMRswGQYDVQQDDBJnaXRsYWIuZXhhbXBsZS5jb20wHhcNMjYw
ODIwMTgxOTA4WhcNMzYwODE3MTgxOTA4WjCBhDELMAkGA1UEBhMCWFgxEjAQBgNV
BAgMCVN0YXRlTmFtZTERMA8GA1UEBwwIQ2l0eU5hbWUxFDASBgNVBAoMC0NvbXBh
bnlOYW1lMRswGQYDVQQLDBJDb21wYW55U2VjdGlvbk5hbWUxGzAZBgNVBAMMEmdp
dGxhYi5leGFtcGxlLmNvbTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
ALo6XPKoQoZTObrusVBuzPa3fbdFPIU3+V3a9NZMP+6r+kzMAq8lPpRm3gRetOqj
dBQAgGPdXuO/FhRm8YNLRuwWCI69ZjvI0w4BLiPVuWLS+NWFQPbggs7uM5RWmf0A
LYV/Og8wbSELqGcb46l31pSaAnBW3oZqM/2+OjxERaOpbXq23P5Py9suR61C9aot
SmlDkkPkvT/0kgISUOObgbMVbmRcs7yP5DRuyyZih2ftxlWXsaaNqvcIMIwyReq4
AlVtDmnovs5c+PGXXTcuuv5fVSFTRwdOPE4SDUSrArQHFFrX/K66LZB9aqXk7M4v
u3cChTDtEC+3D5IbZ2tC7j3FtQ9rfv+U12R3BvWhJkvtG4db5AVy978w6ylAoxHc
SSy2el9Cu21QX/vndkm5pSZfhUE+x2/ysqlTCEUNtGkYjfedA60q8Sytlu0ioRMy
PstE4pNP8Z0arV1HPMBMJcsyogeCV1Cpykcn/prLiuRs5VYNKanDIcq9cn6PZj29
EcvQrRV3mluxZMEjovHiedt1kxQpbWr87b1sEN6hNJl/224UTD5po4kvFiM/Q8mO
JIzjwFY3GWdtUPbH00H8FVnKyWdSL61AXuLV8IkKagoJGJxTG5zz12fiigsByCw9
7bV8QtoRzvuGrDuq4l57znjlulvagsnGhjlRdLacNxwBAgMBAAGjgZIwgY8wHQYD
VR0OBBYEFCAYgN5cahZVOn1oeO1XLhHCib6YMB8GA1UdIwQYMBaAFCAYgN5cahZV
On1oeO1XLhHCib6YMA8GA1UdEwEB/wQFMAMBAf8wPAYDVR0RBDUwM4ISZ2l0bGFi
LmV4YW1wbGUuY29thwSIcXRIghcxMzYuMTEzLjExNi43Mi5zc2xpcC5pbzANBgkq
hkiG9w0BAQsFAAOCAgEAe347cGbyuWGehUfPGlgzh9WxTyxsdsXWvT09bdQRZDcr
8mY40IFU4zHm+vKOc8e54aezszIx1usMJbyyBl/omeiS/XyLhnDjqRBX/l8xUleo
5rPDNiz59fxZU7bdo8jntf7WpR75Zj1CrQTaRtD2FppJMxRb9VMfagHL6U9HIFPr
+tBF42VgT0OgfJTqjbFxIqG2nSOi9DKS2g7E9tSMwWlkw0vtJTqfQyVBgAqxZIsQ
15SUI3oDFlqivfkbbiX50YgvXiG9FS7OuCIs5RM6Y+QpXNJHb+pakRgRNtK+ScVm
UHTXZFB70jWY1k6wMXsNXw3dvibvGGzkq0otf0vlmQoL7sjH2I6cfAMioGi9Y2s7
POLN6nY1Vh50zA8UkcewTKR/EHtqnwdg2kktyG9ZrOh4U03mpnxNrZJA08Qz9ghl
7YlseF9NgZp2PMVMCiYMoTJZ9Ye0x/FNjhcbCGYoCBTvAZfDQsKybEm6XFUIr+Tm
I1Pu71u7NipHNwmYsboXwoubO9YYCicg+Gqhx63KNInA4QqQo4PZblfmgFwOT9Uq
sUb/t1q6x7rsQaFlIQ+vPcsRyiZwKBgyN9EBY8DE2B9M9XKAMOJkNgk74Z2TIZBs
jpsBz4xvORNhw9FOCiN3+sCR4wngYGsgUENYkD1rOp30B9LkyfKFC02f5cW0IOQ=
-----END CERTIFICATE-----
EOF
      }
    },
  }
  projects_re            = "projects/([^/]+)/"
  worker_pool_project    = var.workerpool_id != null ? regex(local.projects_re, var.workerpool_id)[0] : null
  secret_project_numbers = distinct(compact([for cicd in local.cicd_apps : try(regex("projects/([^/]*)/", cicd.cloudbuildv2_repository_config.gitlab_authorizer_credential_secret_id)[0], null)]))
}


resource "google_cloudbuild_worker_pool" "pool" {
  count    = var.workerpool_id == null ? 1 : 0
  name     = "cb-pool-single-project"
  project  = var.project_id
  location = var.region
  worker_config {
    disk_size_gb   = 100
    machine_type   = "e2-standard-4"
    no_external_ip = true
  }
  network_config {
    peered_network          = var.workerpool_network_id
    peered_network_ip_range = "/29"
  }
}

data "google_project" "admin_projects" {
  project_id = var.project_id
}

resource "google_project_iam_member" "assign_permissions" {
  count   = local.worker_pool_project != null ? 1 : 0
  project = local.worker_pool_project
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:service-${data.google_project.admin_projects.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "assign_permissions_service_agent" {
  count   = local.worker_pool_project != null ? 1 : 0
  project = local.worker_pool_project
  role    = "roles/cloudbuild.workerPoolUser"
  member  = "serviceAccount:${data.google_project.admin_projects.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "sd_viewer" {
  count   = local.worker_pool_project != null ? 1 : 0
  project = local.worker_pool_project
  role    = "roles/servicedirectory.viewer"
  member  = "serviceAccount:service-${data.google_project.admin_projects.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "access_network" {
  count   = local.worker_pool_project != null ? 1 : 0
  project = local.worker_pool_project
  role    = "roles/servicedirectory.pscAuthorizedService"
  member  = "serviceAccount:service-${data.google_project.admin_projects.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

resource "time_sleep" "wait_propagation" {
  create_duration = "30s"

  depends_on = [
    google_project_iam_member.assign_permissions,
    google_project_iam_member.assign_permissions_service_agent,
    google_project_iam_member.sd_viewer,
    google_project_iam_member.access_network,
  ]
}

module "cicd" {
  source   = "../../modules/deployment-pipeline"
  for_each = local.cicd_apps

  project_id                 = var.project_id
  region                     = var.region
  env_cluster_membership_ids = local.cluster_membership_ids
  cluster_service_accounts   = { for i, sa in module.multitenant_infra.cluster_service_accounts : (i) => "serviceAccount:${sa}" }

  service_name           = each.value.service_name
  team_name              = each.value.team_name
  repo_name              = each.value.cloudbuildv2_repository_config.repositories[each.value.team_name != each.value.service_name ? "eab-${each.value.application_name}-${each.value.team_name}-${each.value.service_name}" : "eab-${each.value.application_name}-${each.value.service_name}"].repository_name
  repo_branch            = each.value.repo_branch
  app_build_trigger_yaml = "src/${each.value.team_name}/cloudbuild.yaml"

  additional_substitutions = {
    _SERVICE = each.value.service_name
    _TEAM    = each.value.team_name
  }

  ci_build_included_files = ["src/${each.value.team_name}/**", "src/components/**"]

  buckets_force_destroy = true

  cloudbuildv2_repository_config = each.value.cloudbuildv2_repository_config

  workerpool_id = var.workerpool_id == null ? google_cloudbuild_worker_pool.pool[0].id : var.workerpool_id

  logging_bucket             = var.logging_bucket
  bucket_kms_key             = var.bucket_kms_key
  attestation_kms_key        = var.attestation_kms_key
  attestor_id                = var.attestation_kms_key != null ? module.fleetscope_infra.attestor_id : null
  binary_authorization_image = var.binary_authorization_image

  binary_authorization_repository_id = var.binary_authorization_repository_id

  depends_on = [
    google_access_context_manager_service_perimeter_egress_policy.egress_policy,
    google_access_context_manager_service_perimeter_dry_run_egress_policy.egress_policy,
    google_access_context_manager_service_perimeter_ingress_policy.cymbal_bank_private_deployment
  ]
}

data "google_project" "project" {
  project_id = var.project_id
}

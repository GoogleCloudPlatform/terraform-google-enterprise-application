applications = {
  "agent" = {
    "capital-agent" = {
      create_infra_project = false
      create_admin_project = true
    }
  },
  "llm-model" = {
    "llamma-model" = {
      create_infra_project = false
      create_admin_project = true
    }
  }
}

cloudbuildv2_repository_config = {
  repo_type = "GITLABv2"
  repositories = {
    capital-agent = {
      repository_name = "capital-agent-i-r"
      repository_url  = "https://gitlab.example.com/root/capital-agent-i-r.git"
    },
    llamma-model = {
      repository_name = "llamma-model-i-r"
      repository_url  = "https://gitlab.example.com/root/llamma-model-i-r.git"
    },
  }
  # The Secret ID format is: projects/PROJECT_NUMBER/secrets/SECRET_NAME
  gitlab_authorizer_credential_secret_id      = "projects/879050112661/secrets/gitlab-pat-from-vm"
  gitlab_read_authorizer_credential_secret_id = "projects/879050112661/secrets/gitlab-pat-from-vm"
  gitlab_webhook_secret_id                    = "projects/eab-gitlab-mxx6/secrets/gitlab-webhook"
  # If you are using a self-hosted instance, you may change the URL below accordingly
  gitlab_enterprise_host_uri = "https://gitlab.example.com"
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
  secret_project_id                = "eab-gitlab-mxx6"
}

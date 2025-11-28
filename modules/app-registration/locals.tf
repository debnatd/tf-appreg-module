locals {
  user_emails = [
    for id in var.owners : id
    if endswith(id, "@gmail.com")
  ]

  spn_names = [
    for id in var.owners : id
    if !endswith(id, "@gmail.com")
  ]

  api_by_name = {
    for app in distinct([for p in var.api_permissions : replace(p.name, "/\\s+/", "")]) :
    app => [
      for p in var.api_permissions : {
        permission = p.permission
        type       = p.type
      }
      if p.name == app
    ]
  }

  known_app_client_ids = [for d in values(data.azuread_application.known_apps) : d.client_id]

  signing_certificate_end_date = timeadd(
    time_rotating.saml_cert_rotation.rfc3339,
    "${try(var.sso.saml_certificates.validity_in_years, 3) * 8760}h"
  )
}
resource "azuread_application" "this" {
  display_name = var.display_name
  owners = concat(
    [data.azuread_client_config.current.object_id],
    data.azuread_users.users.object_ids,
    data.azuread_service_principals.spns.object_ids
  )
  sign_in_audience = "AzureADMyOrg"

  prevent_duplicate_names = true
  group_membership_claims = var.sso.attributes_and_claims.group_claim.type != null ? [
    var.sso.attributes_and_claims.group_claim.type
  ] : []

  dynamic "web" {
    for_each = var.web != {} ? [var.web] : []
    content {
      homepage_url  = try(web.value.homepage_url, null)
      logout_url    = try(web.value.logout_url, null)
      redirect_uris = try(web.value.redirect_uris, null)
      implicit_grant {
        access_token_issuance_enabled = false
        id_token_issuance_enabled     = false
      }
    }
  }

  dynamic "single_page_application" {
    for_each = length(var.single_page_app_redirect_uris) != 0 ? [1] : []
    content {
      redirect_uris = var.single_page_app_redirect_uris
    }
  }

  dynamic "public_client" {
    for_each = length(var.public_client_redirect_uris) != 0 ? [1] : []
    content {
      redirect_uris = var.public_client_redirect_uris
    }
  }

  dynamic "api" {
    for_each = var.expose_api != {} ? [var.expose_api] : []
    content {
      mapped_claims_enabled          = try(api.value.mapped_claims_enabled, false)
      requested_access_token_version = try(api.value.requested_access_token_version, 2)
      known_client_applications      = local.known_app_client_ids
    }
  }

  # dynamic "optional_claims" {
  #   for_each = var.sso.attributes_and_claims.group_claim != {} ? [var.sso.attributes_and_claims.group_claim] : []
  #   content {
  #     saml2_token {
  #       additional_properties = concat(lower(optional_claims.value.source_attribute) == "groupid" ? [] : (
  #         lower(optional_claims.value.source_attribute) == "samaccountname" ? [
  #           "sam_account_name"
  #           ] : (
  #           lower(optional_claims.value.source_attribute) == "onpremisessecurityidentifier" ? [
  #             "on_premise_security_identifier"
  #             ] : (
  #             lower(optional_claims.value.source_attribute) == "netbiosdomain\\samaccountname" ? [
  #               "netbios_domain_and_sam_account_name"
  #               ] : (
  #               lower(optional_claims.value.source_attribute) == "dnsdomain\\samaccountname" ? [
  #                 "dns_domain_and_sam_account_name"
  #                 ] : (
  #                 lower(optional_claims.value.source_attribute) == "cloudonlygroupdisplaynames" ? [
  #                   "cloud_displayname"
  #                 ] : []
  #               )
  #             )
  #           )
  #         )
  #       ),
  #       optional_claims.value.cloud_only_group == true ? [
  #         "cloud_displayname"
  #       ] : []
  #       )
  #       name = "groups"
  #     }
  #   }
  # }
  # # "NetBIOSDomain\\sAMAccountName", "DNSDomain\\sAMAccountName", "CloudOnlyGroupDisplayNames", "OnPremisesSecurityIdentifier"

  feature_tags {
    custom_single_sign_on = try(var.sso.type, "") == "saml" ? true : false
    enterprise            = length(var.app_role_assignments) > 0 || try(var.sso.type, "") == "saml" ? true : false
  }

  lifecycle {
    ignore_changes = [
      identifier_uris,
      app_role,
      required_resource_access,
      api[0].oauth2_permission_scope,
      tags,
      optional_claims
    ]
  }
}

resource "azuread_application_identifier_uri" "this" {
  for_each = { for idx, uri in var.identifier_uris : idx => uri }

  application_id = azuread_application.this.id
  identifier_uri = each.value
}

resource "azuread_application_api_access" "this" {
  for_each = local.api_by_name

  application_id = azuread_application.this.id
  api_client_id = startswith(each.key, "SP-") ? (
    data.azuread_application.asthete_apps[each.key].client_id
    ) : (
    data.azuread_application_published_app_ids.well_known.result[each.key]
  )

  role_ids = distinct([
    for p in each.value :
    data.azuread_service_principal.api[each.key].app_role_ids[p.permission]
    if p.type == "Application"
  ])

  scope_ids = distinct([
    for p in each.value :
    data.azuread_service_principal.api[each.key].oauth2_permission_scope_ids[p.permission]
    if p.type == "Delegated"
  ])
}

resource "azuread_service_principal" "this" {
  count = try(var.spn.create_spn, true) ? 1 : 0

  client_id                    = azuread_application.this.client_id
  app_role_assignment_required = try(var.spn.app_role_assignment_required, false)
  owners = concat(
    [data.azuread_client_config.current.object_id],
    data.azuread_users.users.object_ids,
    data.azuread_service_principals.spns.object_ids
  )

  preferred_single_sign_on_mode = try(var.sso.type, "")
  login_url                     = try(var.sso.basic_saml_config.sign_on_url, null)

  saml_single_sign_on {
    relay_state = try(var.sso.basic_saml_config.relay_state, null)
  }

  notification_email_addresses = try(var.sso.saml_certificates.notification_email_addresses, [])

  feature_tags {
    custom_single_sign_on = try(var.sso.type, "") == "saml" ? true : false
    enterprise            = length(var.app_role_assignments) > 0 || try(var.sso.type, "") == "saml" ? true : false
  }
}

resource "time_rotating" "saml_cert_rotation" {
  count           = try(var.spn.create_spn, true) && try(var.sso.type, "") == "saml" ? 1 : 0
  rotation_months = (try(var.sso.saml_certificates.validity_in_years, 3) * 12) - 1
}

resource "azuread_service_principal_token_signing_certificate" "token_cert" {
  count                = try(var.spn.create_spn, true) && try(var.sso.type, "") == "saml" ? 1 : 0
  service_principal_id = azuread_service_principal.this[0].id
  display_name         = "CN=${var.sso.saml_certificates.name != null ? var.sso.saml_certificates.name : "Microsoft Azure Federated SSO Certificate"}"
  end_date             = local.signing_certificate_end_date
}

resource "random_uuid" "app_role_uuid" {
  for_each = { for role in var.app_roles : role.display_name => role }
}

resource "azuread_application_app_role" "this" {
  for_each = { for role in var.app_roles : role.display_name => role }

  application_id = azuread_application.this.id
  role_id        = random_uuid.app_role_uuid[each.key].id

  allowed_member_types = (
    lower(each.value.allowed_member_types) == "user/groups" ?
    ["User"] :
    lower(each.value.allowed_member_types) == "application" ?
    ["Application"] :
    ["User", "Application"]
  )
  description  = each.value.description
  display_name = each.value.display_name
  value        = each.value.value
}

resource "random_uuid" "api_scope_uuid" {
  for_each = { for idx, scope in var.expose_api.scopes : idx => scope if var.expose_api != null }
}

resource "azuread_application_permission_scope" "this" {
  for_each = { for idx, scope in var.expose_api.scopes : idx => scope if var.expose_api != null }

  application_id = azuread_application.this.id
  scope_id       = random_uuid.api_scope_uuid[each.key].id
  value          = each.value.value
  type           = each.value.type

  admin_consent_description  = each.value.admin_consent_description
  admin_consent_display_name = each.value.admin_consent_display_name

  user_consent_description  = each.value.type == "User" ? each.value.user_consent_description : null
  user_consent_display_name = each.value.type == "User" ? each.value.user_consent_display_name : null
}

module "app_role_assignments" {
  source   = "../app_role_assignments"
  for_each = { for roles in var.app_role_assignments : roles.role => roles }

  current_app_id   = azuread_service_principal.this[0].object_id
  group_object_ids = try(data.azuread_groups.app_groups[each.key].object_ids, [])
  user_object_ids  = try(data.azuread_users.app_users[each.key].object_ids, [])
  role_id          = azuread_application_app_role.this[each.key].role_id
}

# resource "azuread_claims_mapping_policy" "claims" {
#   #count = length(var.sso.attributes_and_claims)
#   definition = [  ]
#   display_name = "${var.display_name}-claims-mapping-policy"
# }

# resource "azuread_service_principal_claims_mapping_policy_assignment" "claims_assignment" {
#   #count = length(var.sso.attributes_and_claims)
#   service_principal_id = azuread_service_principal.this[0].id
#   claims_mapping_policy_id = azuread_claims_mapping_policy.test.id
# }

# resource "azuread_claims_mapping_policy" "test" {
#   definition = [
#     jsonencode(
#       {
#         ClaimsMappingPolicy = {
#           ClaimsSchema = [
#             {
#               Source = "user"
#               ID     = "preferredlanguage"
#             },
#           ]
#           IncludeBasicClaimSet = "true"
#           Version              = 1
#         }
#       }
#     ),
#   ]
#   display_name = "test_transformation"
# }

resource "azuread_application_optional_claims" "this" {
  count          = local.sso_group_claim.type != null ? 1 : 0
  application_id = azuread_application.this.id

  saml2_token {
    additional_properties = concat(lower(local.sso_group_claim.source_attribute) == "groupid" ? [] : (
      lower(local.sso_group_claim.source_attribute) == "samaccountname" ? [
        "sam_account_name"
        ] : (
        lower(local.sso_group_claim.source_attribute) == "onpremisessecurityidentifier" ? [
          "on_premise_security_identifier"
          ] : (
          lower(local.sso_group_claim.source_attribute) == "netbiosdomain\\samaccountname" ? [
            "netbios_domain_and_sam_account_name"
            ] : (
            lower(local.sso_group_claim.source_attribute) == "dnsdomain\\samaccountname" ? [
              "dns_domain_and_sam_account_name"
              ] : (
              lower(local.sso_group_claim.source_attribute) == "cloudonlygroupdisplaynames" ? [
                "cloud_displayname"
              ] : []
            )
          )
        )
      )
      ),
      local.sso_group_claim.cloud_only_group == true ? [
        "cloud_displayname"
      ] : []
    )
    name = "groups"
  }
  # "NetBIOSDomain\\sAMAccountName", "DNSDomain\\sAMAccountName", "CloudOnlyGroupDisplayNames", "OnPremisesSecurityIdentifier"
}
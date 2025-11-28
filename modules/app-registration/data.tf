data "azuread_client_config" "current" {}

data "azuread_users" "users" {
  user_principal_names = local.user_emails
}

data "azuread_service_principals" "spns" {
  display_names = local.spn_names
}

data "azuread_application_published_app_ids" "well_known" {}

data "azuread_application" "asthete_apps" {
  for_each     = { for idx, app in local.api_by_name : idx => app if startswith(idx, "SP-") }
  display_name = each.key
}

data "azuread_service_principal" "api" {
  for_each = local.api_by_name

  client_id = startswith(each.key, "SP-") ? (
    data.azuread_application.asthete_apps[each.key].client_id
    ) : (
    data.azuread_application_published_app_ids.well_known.result[each.key]
  )
}

data "azuread_application" "known_apps" {
  for_each     = toset(var.expose_api.known_client_applications)
  display_name = each.key
}

data "azuread_application" "internal_apps" {
  for_each     = { for apps in var.app_role_assignments : apps.role => apps if startswith(apps.app_name, "SP-") }
  display_name = each.value.app_name
}

data "azuread_service_principal" "app_roles" {
  for_each = { for apps in var.app_role_assignments : apps.role => apps }

  client_id = startswith(each.value.app_name, "SP-") ? (
    data.azuread_application.internal_apps[each.key].client_id
    ) : (
    data.azuread_application_published_app_ids.well_known.result[each.key]
  )
}

data "azuread_groups" "app_groups" {
  for_each      = { for grps in var.app_role_assignments : grps.role => grps if length(grps.group_names) > 0 }
  display_names = each.value.group_names
}

data "azuread_users" "app_users" {
  for_each             = { for usrs in var.app_role_assignments : usrs.role => usrs if length(usrs.user_names) > 0 }
  user_principal_names = each.value.user_names
}
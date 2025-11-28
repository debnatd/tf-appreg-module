module "app_registration" {
  source   = "./modules/app-registration"
  for_each = { for reg in local.regs : reg.name => reg }

  display_name                  = each.value.name
  identifier_uris               = try(each.value, application_id_uris, [])
  owners                        = try(each.value.owners, [])
  web                           = try(each.value.web, {})
  single_page_app_redirect_uris = try(each.value.single_page_application.redirect_uris, [])
  public_client_redirect_uris   = try(each.value.public_client.redirect_uris, [])
  spn                           = try(each.value.spn, {})
  api_permissions               = try(each.value.api_permissions, [])
  app_roles                     = try(each.value.app_roles, [])
  expose_api                    = try(each.value.expose_api, {})
  sso                           = try(each.value.sso, {})
  app_role_assignments          = try(each.value.app_role_assignments, [])
}
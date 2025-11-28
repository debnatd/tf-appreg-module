output "application" {
  value = azuread_application.this
}

output "application_id_uris" {
  value = azuread_application_identifier_uri.this
}

output "api_permissions" {
  value = azuread_application_api_access.this
}

output "spn" {
  value = azuread_service_principal.this
}

output "app_roles" {
  value = azuread_application_app_role.this
}

output "expose_api" {
  value = azuread_application_permission_scope.this
}

output "owner_spn_obj_id" {
  value = data.azuread_client_config.current.object_id
}

output "app_role_uuid" {
  value = random_uuid.app_role_uuid
}

output "api_scope_uuid" {
  value = random_uuid.api_scope_uuid
}
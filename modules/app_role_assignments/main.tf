# resource "azuread_app_role_assignment" "app" {
#   count               = var.current_app_id != null ? 1 : 0
#   app_role_id         = var.role_id
#   principal_object_id = var.current_app_id
#   resource_object_id  = var.app_object_id
# }

resource "azuread_app_role_assignment" "users" {
  count               = length(var.user_object_ids)
  app_role_id         = var.role_id
  principal_object_id = var.user_object_ids[count.index]
  resource_object_id  = var.current_app_id
}

resource "azuread_app_role_assignment" "groups" {
  count               = length(var.group_object_ids)
  app_role_id         = var.role_id
  principal_object_id = var.group_object_ids[count.index]
  resource_object_id  = var.current_app_id
}
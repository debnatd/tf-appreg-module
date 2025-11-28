variable "display_name" {
  type = string
}

variable "identifier_uris" {
  type = list(string)
}

variable "owners" {
  type = list(string)
}

variable "web" {
  type = object({
    homepage_url  = optional(string)
    logout_url    = optional(string)
    redirect_uris = optional(list(string))
  })
}

variable "single_page_app_redirect_uris" {
  type = list(string)
}

variable "public_client_redirect_uris" {
  type = list(string)
}

variable "spn" {
  type = object({
    create_spn                   = optional(bool, true)
    app_role_assignment_required = optional(bool, false)
  })
  default = {
    create_spn                   = true
    app_role_assignment_required = false
  }
}

variable "api_permissions" {
  type = list(object({
    name       = string
    permission = optional(string)
    type       = optional(string)
  }))

  validation {
    condition = alltrue([
      for p in var.api_permissions :
      p.type == null || contains(["Application", "Delegated"], p.type)
    ])
    error_message = "Must be either of 'Application' or 'Delegated'"
  }
}

variable "app_roles" {
  type = list(object({
    display_name         = optional(string)
    description          = optional(string)
    allowed_member_types = optional(string)
    value                = optional(string)
  }))

  validation {
    condition = alltrue([
      for r in var.app_roles :
      r.allowed_member_types == null ||
      lower(r.allowed_member_types) == "user/groups" ||
      lower(r.allowed_member_types) == "application" ||
      lower(r.allowed_member_types) == "both"
    ])
    error_message = "Allowed member types must be one of 'User/Groups', 'Application' or 'Both'"
  }
}

variable "expose_api" {
  type = object({
    mapped_claims_enabled          = optional(bool, false)
    requested_access_token_version = optional(number, 2)
    known_client_applications      = optional(list(string), [])
    scopes = optional(list(object({
      admin_consent_description  = string
      admin_consent_display_name = string
      user_consent_description   = optional(string, null)
      user_consent_display_name  = optional(string, null)
      type                       = optional(string, "User")
      value                      = optional(string)
    })), [])
  })
}

variable "sso" {
  type = object({
    type = optional(string)
    basic_saml_config = optional(object({
      relay_state = optional(string)
      sign_on_url = optional(string)
    }), {})
    saml_certificates = optional(object({
      notification_email_addresses = optional(list(string), [])
      name                         = optional(string)
      validity_in_years            = optional(number, 3)
    }), {})
    attributes_and_claims = optional(object({
      include_basic_claim_set = optional(bool, true)
      group_claims = optional(list(object({
        group_type        = optional(string)
        soutrce_attribute = optional(string)
        name              = optional(string)
        filter_groups = optional(object({
          attribute_to_match = optional(string)
          match_with         = optional(string)
          string             = optional(string)
        }))
      })), [])
    }), {})
  })
}

variable "app_role_assignments" {
  type = list(object({
    app_name           = optional(string)
    user_names         = optional(list(string), [])
    group_names        = optional(list(string), [])
    role               = optional(string)
    assign_application = optional(bool, false)
  }))
}
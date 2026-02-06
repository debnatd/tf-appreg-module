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

variable "create_spn" {
  type    = bool
  default = true
}

variable "app_role_assignment_required" {
  type    = bool
  default = false
}

variable "notes" {
  type = string
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
      group_claim = optional(object({
        type             = optional(string)
        source_attribute = optional(string, "GroupID")
        cloud_only_group = optional(bool, false)
        # name              = optional(string)
        # filter_groups = optional(object({
        #   attribute_to_match = optional(string)
        #   match_with         = optional(string)
        #   string             = optional(string)
        # }))
      }), {})
    }), {})
  })

  validation {
    condition = (
      try(var.sso.attributes_and_claims.group_claim.source_attribute, null) == null ||
      contains(lower(
        [
          "dnsDomain\\samaccountname",
           "netbiosdomain\\samaccountname", 
           "onpremisessecurityidentifier",
           "samaccountname"
           ]),
            try(var.sso.attributes_and_claims.group_claim.source_attribute, null)
      )
    )
    error_message = "Error"
  }
}

variable "app_role_assignments" {
  type = list(object({
    user_names  = optional(list(string), [])
    group_names = optional(list(string), [])
    role        = optional(string)
  }))
}
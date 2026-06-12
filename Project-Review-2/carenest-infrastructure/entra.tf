# -----------------------------------------------------------------------------
# MANUAL ACTION REQUIRED POST-DEPLOYMENT
# -----------------------------------------------------------------------------
# 1. Navigate to Entra ID -> App Registrations -> jd-carenest-app
# 2. Go to App Roles
# 3. Manually assign Patient role to patient users
# 4. Manually assign Doctor role to doctor users
# -----------------------------------------------------------------------------

data "azuread_client_config" "current" {}

resource "random_uuid" "patient_role_id" {}
resource "random_uuid" "doctor_role_id" {}
resource "random_uuid" "oauth2_permission_scope_id" {}

resource "azuread_application" "app" {
  display_name = "${var.project_name}-app"
  owners       = [data.azuread_client_config.current.object_id]

  web {
    redirect_uris = ["https://${module.frontdoor.frontdoor_endpoint}/"]
    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "Patient role"
    display_name         = "Patient"
    enabled              = true
    id                   = random_uuid.patient_role_id.result
    value                = "Patient"
  }

  app_role {
    allowed_member_types = ["User"]
    description          = "Doctor role"
    display_name         = "Doctor"
    enabled              = true
    id                   = random_uuid.doctor_role_id.result
    value                = "Doctor"
  }

  api {
    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access the user profile."
      admin_consent_display_name = "Read profile"
      enabled                    = true
      id                         = random_uuid.oauth2_permission_scope_id.result
      type                       = "User"
      user_consent_description   = "Allow the application to access your profile."
      user_consent_display_name  = "Read your profile"
      value                      = "User.Read"
    }
  }
}

resource "azuread_service_principal" "sp" {
  client_id                    = azuread_application.app.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "time_rotating" "secret_expiry" {
  rotation_years = 2
}

resource "azuread_service_principal_password" "sp_pwd" {
  service_principal_id = azuread_service_principal.sp.object_id
  rotate_when_changed = {
    rotation = time_rotating.secret_expiry.id
  }
}
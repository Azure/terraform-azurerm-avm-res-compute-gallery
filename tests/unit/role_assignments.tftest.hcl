mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/galleries/gallery_test"
    }
  }

  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
          role_name = "Reader"
        }]
      }
    }
  }
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

variables {
  enable_telemetry = false
  location         = "eastus"
  name             = "gallery_test"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
}

run "resolves_role_names_case_insensitively" {
  command = apply

  variables {
    role_assignments = {
      reader = {
        principal_id                     = "00000000-0000-0000-0000-000000000001"
        role_definition_id_or_name       = "rEaDeR"
        skip_service_principal_aad_check = true
      }
    }

  }

  assert {
    condition = (
      length(azapi_resource.role_assignments) == 1 &&
      azapi_resource.role_assignments["reader"].parent_id == azapi_resource.this.id &&
      azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7" &&
      azapi_resource.role_assignments["reader"].body.properties.principalType == "ServicePrincipal"
    )
    error_message = "Role names must resolve case-insensitively and the legacy skip flag must select ServicePrincipal."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "preserves_explicit_role_assignment_inputs" {
  command = apply

  variables {
    role_assignments = {
      group = {
        name                             = "00000000-0000-0000-0000-000000000002"
        principal_id                     = "00000000-0000-0000-0000-000000000003"
        principal_type                   = "Group"
        role_definition_id_or_name       = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        skip_service_principal_aad_check = true
      }
    }
  }

  assert {
    condition = (
      azapi_resource.role_assignments["group"].name == "00000000-0000-0000-0000-000000000002" &&
      azapi_resource.role_assignments["group"].body.properties.principalType == "Group" &&
      azapi_resource.role_assignments["group"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    )
    error_message = "Explicit names and principal types must be preserved, and tenant role IDs must be subscription-qualified."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

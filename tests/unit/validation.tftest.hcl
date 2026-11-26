mock_provider "azapi" {
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

run "rejects_invalid_gallery_name" {
  command = plan

  variables {
    name = "invalid gallery name"
  }

  expect_failures = [var.name]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "rejects_invalid_lock_kind" {
  command = plan

  variables {
    lock = {
      kind = "Invalid"
    }
  }

  expect_failures = [var.lock]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "rejects_invalid_image_os_state" {
  command = plan

  variables {
    shared_image_definitions = {
      invalid = {
        name     = "invalid"
        os_type  = "Linux"
        os_state = "Invalid"
        identifier = {
          publisher = "Contoso"
          offer     = "Linux"
          sku       = "v1"
        }
      }
    }
  }

  expect_failures = [var.shared_image_definitions]
  providers = {
    azapi  = azapi
    random = random
  }
}

run "rejects_invalid_delegated_managed_identity_id" {
  command = plan

  variables {
    role_assignments = {
      invalid = {
        principal_id                           = "00000000-0000-0000-0000-000000000001"
        role_definition_id_or_name             = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
      }
    }
  }

  expect_failures = [var.role_assignments]
  providers = {
    azapi  = azapi
    random = random
  }
}

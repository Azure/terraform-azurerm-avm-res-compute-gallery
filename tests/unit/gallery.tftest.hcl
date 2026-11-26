mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Compute/galleries/gallery_test"
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

run "omits_optional_resources_by_default" {
  command = apply

  assert {
    condition = (
      length(azapi_resource.shared_image) == 0 &&
      length(azapi_resource.lock) == 0 &&
      length(azapi_resource.role_assignments) == 0 &&
      length(data.azapi_resource_list.role_definitions) == 0 &&
      length(azapi_resource.telemetry) == 0
    )
    error_message = "Optional images, locks, role lookups, assignments and disabled telemetry must not be created."
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.sharingProfile == null &&
      azapi_resource.this.body.properties.softDeletePolicy == null &&
      length(azapi_resource.this.identity) == 0
    )
    error_message = "An unconfigured gallery must not enable sharing, soft delete or managed identities."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "configures_gallery_features_and_lock" {
  command = apply

  variables {
    managed_identities = {
      system_assigned = true
    }
    sharing = {
      permission = "Community"
      community_gallery = {
        eula            = "Test license"
        prefix          = "testgallery"
        publisher_email = "publisher@example.com"
        publisher_uri   = "https://example.com"
      }
    }
    soft_delete_policy = {
      grace_period_in_days     = 7
      is_soft_delete_enabled   = true
      retention_period_in_days = 30
    }
    lock = {
      kind  = "CanNotDelete"
      notes = "Protect gallery images"
    }
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.sharingProfile.permissions == "Community" &&
      azapi_resource.this.body.properties.sharingProfile.communityGalleryInfo.publicNamePrefix == "testgallery" &&
      azapi_resource.this.body.properties.sharingProfile.communityGalleryInfo.publisherContact == "publisher@example.com" &&
      azapi_resource.this.body.properties.sharingProfile.communityGalleryInfo.eula == "Test license" &&
      azapi_resource.this.body.properties.sharingProfile.communityGalleryInfo.publisherUri == "https://example.com"
    )
    error_message = "Community sharing inputs must map to the corresponding ARM properties."
  }

  assert {
    condition = (
      azapi_resource.this.body.properties.softDeletePolicy.gracePeriodInDays == 7 &&
      azapi_resource.this.body.properties.softDeletePolicy.isSoftDeleteEnabled &&
      azapi_resource.this.body.properties.softDeletePolicy.retentionPeriodInDays == 30 &&
      azapi_resource.this.identity[0].type == "SystemAssigned"
    )
    error_message = "Soft delete and the requested managed identity must be configured on the gallery."
  }

  assert {
    condition = (
      length(azapi_resource.lock) == 1 &&
      azapi_resource.lock[0].parent_id == azapi_resource.this.id &&
      azapi_resource.lock[0].name == "lock-CanNotDelete" &&
      azapi_resource.lock[0].body.properties.level == "CanNotDelete" &&
      azapi_resource.lock[0].body.properties.notes == "Protect gallery images"
    )
    error_message = "The generated lock must target the gallery and preserve the requested level and notes."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

run "maps_image_definitions_and_resource_controls" {
  command = apply

  variables {
    retry = {
      error_message_regex = ["AnotherOperationInProgress"]
      interval_seconds    = 5
    }
    timeouts = {
      create = "45m"
      delete = "30m"
      read   = "5m"
      update = "40m"
    }
    shared_image_definitions = {
      linux = {
        name     = "linux"
        os_type  = "Linux"
        os_state = "Generalized"
        identifier = {
          publisher = "Contoso"
          offer     = "Linux"
          sku       = "v1"
        }
        purchase_plan = {
          name      = "linux-plan"
          publisher = "Contoso"
          product   = "Linux"
        }
        features = [{
          name              = "SecurityType"
          starts_at_version = "1.0.0"
          value             = "TrustedLaunchSupported"
        }]
      }
      windows = {
        name     = "windows"
        os_type  = "Windows"
        os_state = "Specialized"
        identifier = {
          publisher = "Contoso"
          offer     = "Windows"
          sku       = "v1"
        }
      }
    }
  }

  assert {
    condition = (
      length(azapi_resource.shared_image) == 2 &&
      azapi_resource.shared_image["linux"].parent_id == azapi_resource.this.id &&
      azapi_resource.shared_image["windows"].parent_id == azapi_resource.this.id &&
      azapi_resource.shared_image["linux"].body.properties.osState == "Generalized" &&
      azapi_resource.shared_image["windows"].body.properties.osState == "Specialized"
    )
    error_message = "Each image definition must retain its map key, gallery parent and OS state."
  }

  assert {
    condition = (
      azapi_resource.shared_image["linux"].body.properties.purchasePlan.product == "Linux" &&
      azapi_resource.shared_image["linux"].body.properties.features[0].startsAtVersion == "1.0.0" &&
      azapi_resource.shared_image["windows"].body.properties.purchasePlan == null &&
      azapi_resource.shared_image["windows"].body.properties.features == null
    )
    error_message = "Image purchase plans and features must map to ARM and remain absent when omitted."
  }

  assert {
    condition = alltrue([
      for image in azapi_resource.shared_image : (
        image.retry.error_message_regex == var.retry.error_message_regex &&
        image.retry.interval_seconds == var.retry.interval_seconds
      )
    ])
    error_message = "Consumer retry settings must be applied to image definitions as well as the gallery."
  }

  assert {
    condition = (
      azapi_resource.this.timeouts == var.timeouts &&
      alltrue([for image in azapi_resource.shared_image : image.timeouts == var.timeouts])
    )
    error_message = "Consumer timeouts must be applied to both the gallery and every image definition."
  }
  providers = {
    azapi  = azapi
    random = random
  }
}

resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = var.parent_id
  type      = var.resource_types.shared_image_gallery
  body = {
    properties = {
      description = var.description
      identifier = {
      }
      sharingProfile = var.sharing != null ? {
        communityGalleryInfo = var.sharing.community_gallery != null ? {
          eula             = var.sharing.community_gallery.eula
          publicNamePrefix = var.sharing.community_gallery.prefix
          publisherContact = var.sharing.community_gallery.publisher_email
          publisherUri     = var.sharing.community_gallery.publisher_uri
        } : null
        permissions = var.sharing.permission
      } : null
      softDeletePolicy = var.soft_delete_policy != null ? {
        gracePeriodInDays     = var.soft_delete_policy.grace_period_in_days
        isSoftDeleteEnabled   = var.soft_delete_policy.is_soft_delete_enabled
        retentionPeriodInDays = var.soft_delete_policy.retention_period_in_days
      } : null
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.shared_image_gallery) > 0 ? var.ignore_body_changes.shared_image_gallery : null
  ignore_null_property   = true
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "identity" {
    for_each = module.avm_interfaces.managed_identities_azapi == null ? [] : [module.avm_interfaces.managed_identities_azapi]

    content {
      type         = identity.value.type
      identity_ids = identity.value.identity_ids
    }
  }

  dynamic "timeouts" {
    for_each = var.timeouts != null ? [var.timeouts] : []

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

moved {
  from = azurerm_shared_image_gallery.this
  to   = azapi_resource.this
}

resource "azapi_resource" "shared_image" {
  for_each = var.shared_image_definitions

  location  = var.location
  name      = each.value.name
  parent_id = azapi_resource.this.id
  type      = var.resource_types.shared_image
  body = {
    properties = {
      allowUpdateImage = each.value.allow_update_image
      architecture     = each.value.architecture
      description      = each.value.description
      disallowed = {
        diskTypes = each.value.disk_types_not_allowed
      }
      endOfLifeDate = each.value.end_of_life_date
      eula          = each.value.eula
      features = each.value.features == null ? null : [
        for feature in each.value.features : {
          name            = feature.name
          startsAtVersion = feature.starts_at_version
          value           = feature.value
        }
      ]
      hyperVGeneration = each.value.hyper_v_generation
      identifier = {
        offer     = each.value.identifier.offer
        publisher = each.value.identifier.publisher
        sku       = each.value.identifier.sku
      }
      osState             = each.value.os_state
      osType              = each.value.os_type
      privacyStatementUri = each.value.privacy_statement_uri
      purchasePlan = each.value.purchase_plan != null ? {
        name      = each.value.purchase_plan.name
        product   = each.value.purchase_plan.product
        publisher = each.value.purchase_plan.publisher
      } : null
      recommended = {
        memory = {
          max = each.value.max_recommended_memory_in_gb
          min = each.value.min_recommended_memory_in_gb
        }
        vCPUs = {
          max = each.value.max_recommended_vcpu_count
          min = each.value.min_recommended_vcpu_count
        }
      }
      releaseNoteUri = each.value.release_note_uri
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.shared_image) > 0 ? var.ignore_body_changes.shared_image : null
  ignore_null_property   = true
  response_export_values = []
  retry                  = var.retry
  tags                   = each.value.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

moved {
  from = azurerm_shared_image.this
  to   = azapi_resource.shared_image
}

# Role definitions are resolved here, case-insensitively as the AzureRM provider did, rather than by
# the interfaces module, whose lookup is case-sensitive. They are listed in the resource group rather
# than on the automation account, so the lookup does not wait for pending changes to the automation account
# and a role name that does not exist fails during plan.
data "azapi_resource_list" "role_definitions" {
  count = length(var.role_assignments) > 0 ? 1 : 0

  parent_id = var.parent_id
  type      = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  response_export_values = {
    results = "value[].{id: id, role_name: properties.roleName}"
  }
}

module "avm_interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.9.0"

  location                                  = var.location
  enable_telemetry                          = var.enable_telemetry
  managed_identities                        = var.managed_identities
  role_assignment_definition_lookup_enabled = false
  role_assignments                          = local.role_assignments
}

resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  name      = coalesce(var.lock.name, "lock-${var.lock.kind}")
  parent_id = azapi_resource.this.id
  type      = var.resource_types.authorization_locks
  body = {
    properties = merge(
      { level = var.lock.kind },
      var.lock.notes == null ? {} : { notes = var.lock.notes },
    )
  }
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  # Create the lock last and remove it first. A ReadOnly lock blocks changes to the child resources.
  depends_on = [
    azapi_resource.this,
  ]
}

moved {
  from = azurerm_management_lock.this
  to   = azapi_resource.lock
}

resource "azapi_resource" "role_assignments" {
  for_each = var.role_assignments

  name                 = module.avm_interfaces.role_assignments_azapi[each.key].name
  parent_id            = azapi_resource.this.id
  type                 = var.resource_types.authorization_role_assignments
  body                 = module.avm_interfaces.role_assignments_azapi[each.key].body
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_casing        = true
  ignore_null_property = true
  # The AzureRM provider replaced a role assignment whenever one of its inputs changed. The inputs are
  # compared, rather than body paths or the resolved role definition ID: Azure normalises role
  # definition IDs, and the role definition lookup is deferred to apply whenever the resource group is
  # not yet known. While the prior value is null, as it is straight after upgrading from AzureRM,
  # nothing is replaced.
  replace_triggers_external_values = {
    condition                              = each.value.condition
    condition_version                      = each.value.condition_version
    delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
    description                            = each.value.description
    principal_id                           = lower(each.value.principal_id)
    principal_type                         = local.role_assignments[each.key].principal_type
    role_definition_id_or_name             = lower(each.value.role_definition_id_or_name)
  }
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    # Upgraded assignments keep the GUID azurerm generated, while the interfaces module generates a
    # new one. Replacing the assignment would fail with ScopeLocked under a CanNotDelete lock.
    ignore_changes = [name]

    precondition {
      condition     = strcontains(lower(local.role_assignments[each.key].role_definition_id_or_name), local.role_definition_resource_substring)
      error_message = "The role definition `${each.value.role_definition_id_or_name}` was not found in the resource group. Use the name of a role definition that can be assigned there, or the role definition's resource ID."
    }
  }
}

moved {
  from = azurerm_role_assignment.this
  to   = azapi_resource.role_assignments
}

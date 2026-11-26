# This ensures we have unique CAF compliant names for our resources.
module "naming" {
  source  = "Azure/avm-utl-naming/azure"
  version = "0.2.0"
}

# This is required for resource modules
resource "azapi_resource" "resource_group" {
  location = var.location
  name     = module.naming.resource_group.name_unique
  type     = "Microsoft.Resources/resourceGroups@2025-04-01"
}

moved {
  from = azurerm_resource_group.this
  to   = azapi_resource.resource_group
}

module "compute_gallery" {
  source = "../../"

  location  = azapi_resource.resource_group.location
  name      = module.naming.shared_image_gallery.name_unique
  parent_id = azapi_resource.resource_group.id
  ## Optional
  description      = "This is a test compute gallery"
  enable_telemetry = var.enable_telemetry
  shared_image_definitions = {
    img01 = {
      name     = "lin-image"
      os_type  = "Linux"
      os_state = "Generalized"
      identifier = {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "810-gen2"
      }
    }
    img02 = {
      name     = "win-image"
      os_type  = "Windows"
      os_state = "Generalized"
      identifier = {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2019-datacenter-gensecond"
      }
    }
  }
}

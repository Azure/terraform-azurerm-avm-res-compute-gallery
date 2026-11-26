variable "location" {
  type        = string
  description = <<DESCRIPTION
(Required) Azure region where the resource should be deployed.
DESCRIPTION
  nullable    = false
}

variable "name" {
  type        = string
  description = <<DESCRIPTION
(Required) Specifies the name of the Shared Image Gallery. Changing this forces a new resource to be created.
DESCRIPTION
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9](?:[A-Za-z0-9._-]{0,78}[A-Za-z0-9])?$", var.name))
    error_message = "The name must be between 1 and 80characters long and can only contain lowercase letters and numbers."
  }
}

# This is required for most resource modules
variable "parent_id" {
  type        = string
  description = "The fully-qualified ARM resource ID of the existing resource group into which the Compute Gallery will be deployed."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a valid Azure resource group resource ID."
  }
}

variable "description" {
  type        = string
  default     = null
  description = "(Optional) The description of the shared image gallery"
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "ignore_body_changes" {
  type = object({
    authorization_locks            = optional(list(string), [])
    authorization_role_assignments = optional(list(string), [])
    shared_image_gallery           = optional(list(string), [])
    shared_image                   = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Body-relative paths to ignore for module-owned resources. Paths use dot notation. Changes take effect only after apply. Ignored configuration is not sent to Azure until the path is removed. Non-empty values require Terraform 1.11 or later.

- `authorization_locks` - Paths ignored on account and private endpoint locks.
- `authorization_role_assignments` - Paths ignored on account and private endpoint role assignments.
- `shared_image_gallery` - Paths ignored on shared image galleries.
- `shared_image` - Paths ignored on shared images.
DESCRIPTION
  nullable    = false
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
  Controls the Resource Lock configuration for this resource. The following properties can be specified:

  - `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
  - `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
  - `notes` - (Optional) Notes about the lock. This value maps to `Microsoft.Authorization/locks.properties.notes`.
  DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
  Controls the Managed Identity configuration on this resource. The following properties can be specified:

  - `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
  - `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.
  DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for id in var.managed_identities.user_assigned_resource_ids :
      can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", id))
    ])
    error_message = "Each entry in `managed_identities.user_assigned_resource_ids` must be a valid user-assigned managed identity resource ID."
  }
}

variable "resource_types" {
  type = object({
    authorization_locks            = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    authorization_role_assignments = optional(string, "Microsoft.Authorization/roleAssignments@2022-04-01")
    shared_image_gallery           = optional(string, "Microsoft.Compute/galleries@2026-03-03")
    shared_image                   = optional(string, "Microsoft.Compute/galleries/images@2026-03-03")
  })
  default     = {}
  description = <<DESCRIPTION
AzAPI resource types and API versions used by the module.
- `authorization_locks` - Resource type and API version for account and private endpoint locks.
- `authorization_role_assignments` - Resource type and API version for account and private endpoint role assignments.
- `shared_image_gallery` - Resource type and API version for shared image galleries.
- `shared_image` - Resource type and API version for shared images.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default = {
    error_message_regex = ["ScopeLocked", "Cannot delete resource while nested resources exist"]
  }
  description = <<DESCRIPTION
Retry configuration applied to every supported AzAPI resource declared by the module. By default, retries ScopeLocked errors during lock removal propagation and transient gallery deletion errors while Azure still reports deleted child resources. Set to null for provider defaults.

- `error_message_regex` - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds` - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.
DESCRIPTION
}

variable "role_assignments" {
  type = map(object({
    name                                   = optional(string, null)
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of role assignments to create on the Compute Gallery. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

- `name` - (Optional) The name of the role assignment. If not set, a random UUID will be generated. Changing this forces the creation of a new resource.
- `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
- `principal_id` - The ID of the principal to assign the role to.
- `description` - (Optional) The description of the role assignment.
- `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
- `condition` - (Optional) The condition which will be used to scope the role assignment.
- `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
- `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
- `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

> Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.role_assignments :
      v.delegated_managed_identity_resource_id == null || can(provider::azapi::parse_resource_id("Microsoft.ManagedIdentity/userAssignedIdentities", v.delegated_managed_identity_resource_id))
    ])
    error_message = "Each `role_assignments[*].delegated_managed_identity_resource_id` must be a valid user-assigned managed identity resource ID, or null."
  }
}

variable "shared_image_definitions" {
  type = map(object({
    name = string
    identifier = object({
      publisher = string
      offer     = string
      sku       = string
    })
    os_type  = string
    os_state = string
    purchase_plan = optional(object({
      name      = string
      publisher = optional(string)
      product   = optional(string)
    }))
    description                         = optional(string)
    disk_controller_type_nvme_enabled   = optional(bool)
    disk_types_not_allowed              = optional(list(string), [])
    end_of_life_date                    = optional(string)
    eula                                = optional(string)
    architecture                        = optional(string, "x64")
    hyper_v_generation                  = optional(string, "V1")
    max_recommended_vcpu_count          = optional(number)
    min_recommended_vcpu_count          = optional(number)
    max_recommended_memory_in_gb        = optional(number)
    min_recommended_memory_in_gb        = optional(number)
    privacy_statement_uri               = optional(string)
    release_note_uri                    = optional(string)
    trusted_launch_enabled              = optional(bool)
    confidential_vm_supported           = optional(bool)
    confidential_vm_enabled             = optional(bool)
    accelerated_network_support_enabled = optional(bool)
    allow_update_image                  = optional(bool)
    features = optional(list(object({
      name              = string
      starts_at_version = string
      value             = string
    })))
    tags = optional(map(string))
  }))
  default     = {}
  description = <<DESCRIPTION
A map to create on the Key shared image definitions
- `name` - (Required) Specifies the name of the Shared Image. Changing this forces a new resource to be created.
- `identifier` - (Required) An identifier object as defined below.
  - `publisher` - (Required) The Publisher Name for this Gallery Image. Changing this forces a new resource to be created.
  - `offer` - (Required) The Offer Name for this Shared Image. Changing this forces a new resource to be created.
  - `sku` - (Required) The Name of the SKU for this Gallery Image. Changing this forces a new resource to be created.
- `os_state` - (Required) Specifies the state of the Operating System inside this Image. Possible values are Generalized and Specialized. Changing this forces a new resource to be created.
- `os_type`  - (Required) The type of Operating System present in this Shared Image. Possible values are Linux and Windows. Changing this forces a new resource to be created.
- `purchase_plan` - (Optional) A purchase_plan object as defined below.
  - `name` - (Required) The Purchase Plan Name for this Shared Image. Changing this forces a new resource to be created.
  - `publisher` - (Optional) The Purchase Plan Publisher for this Gallery Image. Changing this forces a new resource to be created.
  - `product` - (Optional) The Purchase Plan Product for this Gallery Image. Changing this forces a new resource to be created.
- `description` - (Optional) A description of this Shared Image.
- `disk_controller_type_nvme_enabled` - (Optional) Specifies if the Shared Image supports NVMe disks. Changing this forces a new resource to be created.
- `disk_types_not_allowed` - (Optional) One or more Disk Types not allowed for the Image. Possible values include Standard_LRS and Premium_LRS.
- `end_of_life_date` - (Optional) The end of life date in RFC3339 format of the Image.
- `eula` - (Optional) The End User Licence Agreement for the Shared Image. Changing this forces a new resource to be created.
> Note: It's recommended to Generalize images where possible - Specialized Images reuse the same UUID internally within each Virtual Machine, which can have unintended side-effects.
- `architecture` - (Optional) CPU architecture supported by an OS. Possible values are x64 and Arm64. Defaults to x64. Changing this forces a new resource to be created.
- `hyper_v_generation` - (Optional) The generation of HyperV that the Virtual Machine used to create the Shared Image is based on. Possible values are V1 and V2. Defaults to V1. Changing this forces a new resource to be created.
- `max_recommended_vcpu_count` - (Optional) Maximum count of vCPUs recommended for the Image.
- `min_recommended_vcpu_count` - (Optional) Minimum count of vCPUs recommended for the Image.
- `max_recommended_memory_in_gb` - (Optional) Maximum memory in GB recommended for the Image.
- `min_recommended_memory_in_gb` - (Optional) Minimum memory in GB recommended for the Image.
- `privacy_statement_uri` - (Optional) The URI containing the Privacy Statement associated with this Shared Image. Changing this forces a new resource to be created.
- `release_note_uri` - (Optional) The URI containing the Release Notes associated with this Shared Image.
- `trusted_launch_supported` - (Optional) Specifies if supports creation of both Trusted Launch virtual machines and Gen2 virtual machines with standard security created from the Shared Image. Changing this forces a new resource to be created.
- `trusted_launch_enabled` - (Optional) Specifies if Trusted Launch has to be enabled for the Virtual Machine created from the Shared Image. Changing this forces a new resource to be created.
- `confidential_vm_supported` - (Optional) Specifies if supports creation of both Confidential virtual machines and Gen2 virtual machines with standard security from a compatible Gen2 OS disk VHD or Gen2 Managed image. Changing this forces a new resource to be created.
- `confidential_vm_enabled` - (Optional) Specifies if Confidential Virtual Machines enabled. It will enable all the features of trusted, with higher confidentiality features for isolate machines or encrypted data. Available for Gen2 machines. Changing this forces a new resource to be created.
- `accelerated_network_support_enabled` - (Optional) Specifies if the Shared Image supports Accelerated Network. Changing this forces a new resource to be created.
- `allow_update_image` - (Optional) Specifies whether updating the image is allowed.
- `features` - (Optional) A list of features associated with this Shared Image. Each feature includes a `name`, `starts_at_version`, and `value`.
- `tags` - (Optional) A mapping of tags to assign to the Shared Image.
> Note: Only one of `trusted_launch_supported`, `trusted_launch_enabled`, `confidential_vm_supported` and `confidential_vm_enabled` can be specified.
DESCRIPTION

  validation {
    condition     = alltrue([for si in var.shared_image_definitions : contains(["Generalized", "Specialized"], si.os_state)])
    error_message = "Each value `shared_image_definitions[*].os_state` must be either 'Generalized' or 'Specialized'"
  }
}

variable "sharing" {
  type = object({
    permission = string
    community_gallery = optional(object({
      eula            = string
      prefix          = string
      publisher_email = string
      publisher_uri   = string
    }))
  })
  default     = null
  description = <<DESCRIPTION
A sharing object that supports the following:
- `permission` - (Required) The permission of the Shared Image Gallery when sharing. Possible values are Community, Groups and Private. Changing this forces a new resource to be created.
> Note: This requires that the Preview Feature Microsoft.Compute/CommunityGalleries is enabled, see the documentation for more information.
- `community_gallery` - (Optional) A community_gallery object that supports the following:
  - `eula` - (Required) The End User Licence Agreement for the Shared Image Gallery. Changing this forces a new resource to be created.
  - `prefix` - (Required) Prefix of the community public name for the Shared Image Gallery. Changing this forces a new resource to be created.
  - `publisher_email` - (Required) Email of the publisher for the Shared Image Gallery. Changing this forces a new resource to be created.
  - `publisher_uri` - (Required) URI of the publisher for the Shared Image Gallery. Changing this forces a new resource to be created.
> Note: `community_gallery` must be set when `permission` is set to `Community`.
DESCRIPTION
}

variable "soft_delete_policy" {
  type = object({
    grace_period_in_days     = number
    is_soft_delete_enabled   = bool
    retention_period_in_days = number
  })
  default     = null
  description = <<DESCRIPTION
A soft delete policy object that supports the following:
- `grace_period_in_days` - (Required) The grace period in days for the soft delete policy.
- `is_soft_delete_enabled` - (Required) Whether soft delete is enabled.
- `retention_period_in_days` - (Required) The retention period in days for the soft delete policy.
DESCRIPTION
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    delete = optional(string)
    read   = optional(string)
    update = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
 - `create` - (Defaults to 60 minutes) Used when creating the Shared Image Gallery.
 - `delete` - (Defaults to 60 minutes) Used when deleting the Shared Image Gallery.
 - `read` - (Defaults to 5 minutes) Used when retrieving the Shared Image Gallery.
 - `update` - (Defaults to 60 minutes) Used when updating the Shared Image Gallery.
DESCRIPTION
}

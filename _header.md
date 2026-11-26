# Azure Compute Gallery

This Azure Verified Module manages an Azure Compute Gallery and optional image definitions, role assignments, managed identities and a resource lock using the AzAPI provider. The parent resource group must already exist.

Terraform 1.11 or later and AzAPI 2.12 or later within major version 2 are required. Supply `name`, `location` and the existing resource group's ARM ID as `parent_id`.

## Examples

- [Defaults](examples/defaults): creates a gallery in a resource group provisioned by the example.
- [With images](examples/with-images): creates a gallery with Linux and Windows image definitions.

Both examples expose the gallery's `resource_id`. They accept separate location and telemetry controls. The image example does not provision image versions or virtual machines.

## Upgrading from the AzureRM implementation

This migration changes the provider and introduces breaking input changes compared with version `0.3.0`:

- Replace `resource_group_name` with `parent_id`, using the full ARM ID of the existing resource group.
- Replace each image definition's `specialized` flag with `os_state`: use `Specialized` for `true`, and `Generalized` for `false` or an omitted flag.
- Review the new `resource_types`, `retry` and `ignore_body_changes` inputs. Resource API versions can be overridden without changing module code.

Keep the module call address and all image and role-assignment map keys unchanged. The module includes `moved` blocks for the gallery, image definitions, lock and role assignments:

| Previous resource address | New resource address |
| --- | --- |
| `azurerm_shared_image_gallery.this` | `azapi_resource.this` |
| `azurerm_shared_image.this` | `azapi_resource.shared_image` |
| `azurerm_management_lock.this` | `azapi_resource.lock` |
| `azurerm_role_assignment.this` | `azapi_resource.role_assignments` |

Back up state and inspect the migration plan before applying:

```powershell
terraform state pull | Out-File -FilePath before-azapi.tfstate -Encoding utf8
terraform init -upgrade
terraform plan -out=migration.tfplan
```

Do not apply a plan containing unexpected deletions or replacements. Review any in-place changes to optional resource properties, then apply the saved plan and check again:

```powershell
terraform apply migration.tfplan
terraform plan
```

With telemetry enabled, generated empty telemetry deployments intentionally update on each normal plan. This does not indicate drift in the gallery or its image definitions. Consumers can disable telemetry throughout the module graph with `enable_telemetry = false`.

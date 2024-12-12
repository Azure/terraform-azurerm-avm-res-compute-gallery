output "name" {
  description = "The Unique Name for this Shared Image Gallery."
  value       = azurerm_shared_image_gallery.name.unique_name
}

output "resource_id" {
  description = "The ID of the Shared Image Gallery."
  value       = azurerm_shared_image_gallery.name.id
}

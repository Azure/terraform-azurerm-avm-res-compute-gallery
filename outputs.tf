output "id" {
  value       = azurerm_shared_image_gallery.name.id
  description = "The ID of the Shared Image Gallery."
}

output "name" {
  value = azurerm_shared_image_gallery.name.unique_name
  description = "The Unique Name for this Shared Image Gallery."
}


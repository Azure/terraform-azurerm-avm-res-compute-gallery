output "name" {
  description = "The name of the Image Gallery."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "The id of the Image Gallery."
  value       = azapi_resource.this.id
}

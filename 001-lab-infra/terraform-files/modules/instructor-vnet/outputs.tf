output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "transit_subnet_id" {
  value = azurerm_subnet.transit.id
}

output "management_subnet_id" {
  value = azurerm_subnet.management.id
}

output "services_subnet_id" {
  value = azurerm_subnet.services.id
}

output "internal_subnet_id" {
  value = azurerm_subnet.internal.id
}
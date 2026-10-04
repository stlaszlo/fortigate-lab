output "vm_id" {
  value = azurerm_linux_virtual_machine.this.id
}

output "management_public_ip" {
  value = var.create_management_public_ip ? azurerm_public_ip.management[0].ip_address : null
}

output "port1_private_ip" {
  value = azurerm_network_interface.port1.private_ip_address
}

output "port2_private_ip" {
  value = azurerm_network_interface.port2.private_ip_address
}

output "port3_private_ip" {
  value = azurerm_network_interface.port3.private_ip_address
}
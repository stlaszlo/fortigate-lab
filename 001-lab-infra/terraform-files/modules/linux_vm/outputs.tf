output "id" {
  description = "VM resource ID."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "VM name."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip" {
  description = "Private IP address."
  value       = azurerm_network_interface.this.private_ip_address
}

output "nic_id" {
  description = "NIC resource ID."
  value       = azurerm_network_interface.this.id
}

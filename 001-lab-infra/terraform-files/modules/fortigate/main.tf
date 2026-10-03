resource "azurerm_public_ip" "management" {
  name                = "${var.name}-pip-mgmt"
  location            = var.location
  resource_group_name = var.resource_group_name

  allocation_method = "Static"
  sku               = "Standard"

  tags = var.tags
}

resource "azurerm_network_interface" "port1" {
  name                = "${var.name}-nic-port1"
  location            = var.location
  resource_group_name = var.resource_group_name
  accelerated_networking_enabled = true
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "port1"
    subnet_id                     = var.transit_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_network_interface" "port2" {
  name                = "${var.name}-nic-port2"
  location            = var.location
  resource_group_name = var.resource_group_name
  accelerated_networking_enabled = true
  ip_forwarding_enabled = true

  ip_configuration {
    name                          = "port2"
    subnet_id                     = var.internal_subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_network_interface" "port3" {
  name                = "${var.name}-nic-port3"
  location            = var.location
  resource_group_name = var.resource_group_name
  accelerated_networking_enabled = true
  ip_configuration {
    name                          = "port3"
    subnet_id                     = var.management_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.management.id
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name

  size = var.vm_size

  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.port1.id,
    azurerm_network_interface.port2.id,
    azurerm_network_interface.port3.id
  ]

  plan {
    publisher = "fortinet"
    product   = "fortinet_fortigate-vm"
    name      = "fortinet_fg-vm_payg_76_g2"
  }

  source_image_reference {
    publisher = "fortinet"
    offer     = "fortinet_fortigate-vm"
    sku       = "fortinet_fg-vm_payg_76_g2"
    version   = "7.6.7"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  tags = var.tags
}
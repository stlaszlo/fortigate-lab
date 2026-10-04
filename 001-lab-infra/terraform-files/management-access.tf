resource "azurerm_network_security_group" "instructor_management" {
  name                = "nsg-management"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Instructor_Hub"
    owner   = "Laszlo"
  }
}

resource "azurerm_network_security_rule" "instructor_https" {
  name                        = "Allow-HTTPS"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = var.my_public_ip
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.cohort.name
  network_security_group_name = azurerm_network_security_group.instructor_management.name
}

resource "azurerm_network_security_rule" "instructor_ssh" {
  name                        = "Allow-SSH"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.my_public_ip
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.cohort.name
  network_security_group_name = azurerm_network_security_group.instructor_management.name
}

resource "azurerm_subnet_network_security_group_association" "instructor_management" {
  subnet_id                 = module.instructor_network.subnet_ids["management"]
  network_security_group_id = azurerm_network_security_group.instructor_management.id
}
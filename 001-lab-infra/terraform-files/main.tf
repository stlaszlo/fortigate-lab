module "instructor_vnet" {
  source = "./modules/instructor-vnet"

  name                = "vnet-fortinet-instructor"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.cohort.name
  my_public_ip        = var.my_public_ip
  address_space       = "10.0.0.0/16"
  transit_subnet      = "10.0.0.0/24"
  management_subnet   = "10.0.10.0/24"
  services_subnet     = "10.0.20.0/24"
  internal_subnet     = "10.0.30.0/24"

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Instructor_Hub"
    owner   = "Laszlo"
  }
}
module "instructor_fortigate" {
  source = "./modules/fortigate"

  name                = "fg-instructor-01"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  vm_size = "Standard_D4s_v7"

  transit_subnet_id    = module.instructor_vnet.transit_subnet_id
  internal_subnet_id   = module.instructor_vnet.internal_subnet_id
  management_subnet_id = module.instructor_vnet.management_subnet_id

  admin_username = "laciadmin"
  admin_password = var.fortigate_admin_password

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Instructor_FortiGate"
    owner   = "Laszlo"
  }
}
module "instructor_network" {
  source = "./modules/network-pod"

  name                = "vnet-fortinet-instructor"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  address_space = "10.0.0.0/16"

  subnets = {
    transit = {
      name           = "snet-transit"
      address_prefix = "10.0.0.0/24"
    }

    management = {
      name           = "snet-management"
      address_prefix = "10.0.10.0/24"
    }

    services = {
      name           = "snet-services"
      address_prefix = "10.0.20.0/24"
    }

    internal = {
      name           = "snet-internal"
      address_prefix = "10.0.30.0/24"
    }
  }

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

  port1_subnet_id = module.instructor_network.subnet_ids["transit"]
  port2_subnet_id = module.instructor_network.subnet_ids["internal"]
  port3_subnet_id = module.instructor_network.subnet_ids["management"]

  admin_username              = var.instructor_admin_username
  admin_password              = var.instructor_admin_password
  port1_ip                    = "10.0.0.4"
  port2_ip                    = "10.0.30.4"
  port3_ip                    = "10.0.10.4"
  create_management_public_ip = true
  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Instructor_FortiGate"
    owner   = "Laszlo"
  }
}
locals {
  student_pods = {
    student01 = {
      octet    = 1
      username = "student01"
    }
    student02 = {
      octet    = 2
      username = "student02"
    }
    student03 = {
      octet    = 3
      username = "student03"
    }
    student04 = {
      octet    = 4
      username = "student04"
    }
    student05 = {
      octet    = 5
      username = "student05"
    }
    student06 = {
      octet    = 6
      username = "student06"
    }
    student07 = {
      octet    = 7
      username = "student07"
    }
    student08 = {
      octet    = 8
      username = "student08"
    }
  }
}
module "student_network" {
  source   = "./modules/network-pod"
  for_each = local.student_pods

  name                = "vnet-fortinet-${each.key}"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  address_space = "10.${each.value.octet}.0.0/16"

  subnets = {
    wan = {
      name           = "snet-wan"
      address_prefix = "10.${each.value.octet}.0.0/24"
    }

    lan = {
      name           = "snet-lan"
      address_prefix = "10.${each.value.octet}.10.0/24"
    }

    dmz = {
      name           = "snet-dmz"
      address_prefix = "10.${each.value.octet}.20.0/24"
    }
  }

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Student_Pod"
    Student = each.key
    owner   = "Laszlo"
  }
}

resource "azurerm_virtual_network_peering" "instructor_to_student" {
  for_each = module.student_network

  name                      = "peer-instructor-to-${each.key}"
  resource_group_name       = data.azurerm_resource_group.cohort.name
  virtual_network_name      = module.instructor_network.vnet_name
  remote_virtual_network_id = each.value.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  use_remote_gateways = false
}

resource "azurerm_virtual_network_peering" "student_to_instructor" {
  for_each = module.student_network

  name                      = "peer-${each.key}-to-instructor"
  resource_group_name       = data.azurerm_resource_group.cohort.name
  virtual_network_name      = each.value.vnet_name
  remote_virtual_network_id = module.instructor_network.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  use_remote_gateways = false
}

module "router_nva" {
  source = "./modules/router-nva"

  name                = "nva-router-01"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  subnet_id          = module.instructor_network.subnet_ids["transit"]
  private_ip_address = "10.0.0.5"

  upstream_gateway = "10.0.0.4"

  admin_username = var.router_admin_username
  admin_password = var.router_admin_password

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Transit_Router"
    owner   = "Laszlo"
  }
}

resource "azurerm_route" "transit_default_via_instructor_fg" {
  name                   = "default-via-instructor-fg"
  resource_group_name    = data.azurerm_resource_group.cohort.name
  route_table_name       = module.instructor_network.route_table_names["transit"]
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.0.0.4"
}

resource "azurerm_route" "student_wan_default_via_router" {
  for_each = module.student_network

  name                   = "default-via-transit-router"
  resource_group_name    = data.azurerm_resource_group.cohort.name
  route_table_name       = each.value.route_table_names["wan"]
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = module.router_nva.private_ip
}
module "student01_fortigate" {
  source = "./modules/fortigate"

  name                = "fg-student01"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  vm_size = "Standard_D2s_v7"

  port1_subnet_id = module.student_network["student01"].subnet_ids["wan"]
  port2_subnet_id = module.student_network["student01"].subnet_ids["lan"]
  port3_subnet_id = module.student_network["student01"].subnet_ids["dmz"]

  port1_ip = "10.${local.student_pods["student01"].octet}.0.4"
  port2_ip = "10.${local.student_pods["student01"].octet}.10.4"
  port3_ip = "10.${local.student_pods["student01"].octet}.20.4"

  admin_username = local.student_pods["student01"].username
  admin_password = var.student_admin_password

  create_management_public_ip = false

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Student_FortiGate"
    Student = "student01"
    owner   = "Laszlo"
  }
}
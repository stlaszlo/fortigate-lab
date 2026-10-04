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
    nva = {
      name           = "snet-nva"
      address_prefix = "10.0.40.0/24"
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
  router_nva_ip = "10.0.40.4"
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

  subnet_id          = module.instructor_network.subnet_ids["nva"]
  private_ip_address = "10.0.40.4"

  admin_username = var.router_admin_username
  admin_password = var.router_admin_password

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Transit_Router"
    owner   = "Laszlo"
  }
}

resource "azurerm_route" "nva_default_via_instructor_fg" {
  name                   = "default-via-instructor-fg"
  resource_group_name    = data.azurerm_resource_group.cohort.name
  route_table_name       = module.instructor_network.route_table_names["nva"]
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = module.instructor_fortigate.port1_private_ip
}

resource "azurerm_route" "instructor_transit_student_via_router" {
  for_each = local.student_pods

  name                   = "${each.key}-via-transit-router"
  resource_group_name    = data.azurerm_resource_group.cohort.name
  route_table_name       = module.instructor_network.route_table_names["transit"]
  address_prefix         = "10.${each.value.octet}.0.0/16"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.router_nva_ip
}

resource "azurerm_route" "student_wan_default_via_router" {
  for_each = module.student_network

  name                   = "default-via-transit-router"
  resource_group_name    = data.azurerm_resource_group.cohort.name
  route_table_name       = each.value.route_table_names["wan"]
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.router_nva_ip
}

module "student_fortigate" {
  source   = "./modules/fortigate"
  for_each = local.student_pods

  name                = "fg-${each.key}"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  vm_size = "Standard_D2s_v7"

  port1_subnet_id = module.student_network[each.key].subnet_ids["wan"]
  port2_subnet_id = module.student_network[each.key].subnet_ids["lan"]
  port3_subnet_id = module.student_network[each.key].subnet_ids["dmz"]

  port1_ip = "10.${each.value.octet}.0.4"
  port2_ip = "10.${each.value.octet}.10.4"
  port3_ip = "10.${each.value.octet}.20.4"

  admin_username = each.value.username
  admin_password = var.student_admin_password

  create_management_public_ip = false

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Student_FortiGate"
    Student = each.key
    owner   = "Laszlo"
  }
}
resource "azurerm_route" "student_lan_default_via_fortigate" {
  for_each = local.student_pods

  name                   = "default-via-student-fortigate"
  resource_group_name    = data.azurerm_resource_group.cohort.name
  route_table_name       = module.student_network[each.key].route_table_names["lan"]
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.${each.value.octet}.10.4"
}

resource "azurerm_route" "student_dmz_default_via_fortigate" {
  for_each = local.student_pods

  name                   = "default-via-student-fortigate"
  resource_group_name    = data.azurerm_resource_group.cohort.name
  route_table_name       = module.student_network[each.key].route_table_names["dmz"]
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.${each.value.octet}.20.4"
}

resource "azurerm_route" "student_lan_to_dmz_via_fortigate" {
  for_each = local.student_pods

  name                   = "dmz-via-student-fortigate"
  resource_group_name    = data.azurerm_resource_group.cohort.name
  route_table_name       = module.student_network[each.key].route_table_names["lan"]
  address_prefix         = "10.${each.value.octet}.20.0/24"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.${each.value.octet}.10.4"
}

resource "azurerm_route" "student_dmz_to_lan_via_fortigate" {
  for_each = local.student_pods

  name                   = "lan-via-student-fortigate"
  resource_group_name    = data.azurerm_resource_group.cohort.name
  route_table_name       = module.student_network[each.key].route_table_names["dmz"]
  address_prefix         = "10.${each.value.octet}.10.0/24"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.${each.value.octet}.20.4"
}

module "student_client" {
  source   = "./modules/linux_vm"
  for_each = local.student_pods

  name                = "vm-${each.key}-client"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  subnet_id  = module.student_network[each.key].subnet_ids["lan"]
  private_ip = "10.${each.value.octet}.10.10"

  role    = "client"
  vm_size = "Standard_B2s_v2"

  admin_username = each.value.username
  admin_password = var.student_admin_password

  motd = <<-EOT
    Fortinet Training Lab

    Student: ${each.key}
    Role:    Client

    IP:      10.${each.value.octet}.10.10
    Gateway: 10.${each.value.octet}.10.4
    DMZ:     10.${each.value.octet}.20.10
  EOT

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Student_Client"
    Student = each.key
    owner   = "Laszlo"
  }
}

module "student_dmz" {
  source   = "./modules/linux_vm"
  for_each = local.student_pods

  name                = "vm-${each.key}-dmz"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  subnet_id  = module.student_network[each.key].subnet_ids["dmz"]
  private_ip = "10.${each.value.octet}.20.10"

  role    = "server"
  vm_size = "Standard_B2s_v2"

  admin_username = each.value.username
  admin_password = var.student_admin_password

  motd = <<-EOT
    Fortinet Training Lab
    Student: ${each.key}
    Role:    DMZ Server
    IP:      10.${each.value.octet}.20.10
    Gateway: 10.${each.value.octet}.20.4
  EOT

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Student_DMZ_Server"
    Student = each.key
    owner   = "Laszlo"
  }
}
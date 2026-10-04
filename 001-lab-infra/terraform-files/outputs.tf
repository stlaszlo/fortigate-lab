output "cohort_rg_location" {
  value = data.azurerm_resource_group.cohort.location
}

output "cohort_rg_id" {
  value = data.azurerm_resource_group.cohort.id
}

output "instructor_vnet_id" {
  value = module.instructor_network.vnet_id
}

output "instructor_vnet_name" {
  value = module.instructor_network.vnet_name
}
output "instructor_transit_subnet_id" {
  value = module.instructor_network.subnet_ids["transit"]
}

output "instructor_management_subnet_id" {
  value = module.instructor_network.subnet_ids["management"]
}

output "instructor_services_subnet_id" {
  value = module.instructor_network.subnet_ids["services"]
}

output "instructor_internal_subnet_id" {
  value = module.instructor_network.subnet_ids["internal"]
}
output "instructor_fortigate_management_ip" {
  value = module.instructor_fortigate.management_public_ip
}

output "instructor_fortigate_port1_ip" {
  value = module.instructor_fortigate.port1_private_ip
}

output "instructor_fortigate_port2_ip" {
  value = module.instructor_fortigate.port2_private_ip
}

output "instructor_fortigate_port3_ip" {
  value = module.instructor_fortigate.port3_private_ip
}

output "student_vnet_ids" {
  value = {
    for key, pod in module.student_network :
    key => pod.vnet_id
  }
}

output "student_subnet_ids" {
  value = {
    for key, pod in module.student_network :
    key => pod.subnet_ids
  }
}
output "router_nva_private_ip" {
  value = module.router_nva.private_ip
}

output "student_client_private_ips" {
  description = "Private IP addresses of all student LAN client VMs."
  value = {
    for student, vm in module.student_client :
    student => vm.private_ip
  }
}

output "student_dmz_private_ips" {
  description = "Private IP addresses of all student DMZ server VMs."
  value = {
    for student, vm in module.student_dmz :
    student => vm.private_ip
  }
}
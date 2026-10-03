output "cohort_rg_location" {
  value = data.azurerm_resource_group.cohort.location
}

output "cohort_rg_id" {
  value = data.azurerm_resource_group.cohort.id
}

output "instructor_vnet_id" {
  value = module.instructor_vnet.vnet_id
}

output "instructor_vnet_name" {
  value = module.instructor_vnet.vnet_name
}

output "instructor_transit_subnet_id" {
  value = module.instructor_vnet.transit_subnet_id
}

output "instructor_management_subnet_id" {
  value = module.instructor_vnet.management_subnet_id
}

output "instructor_services_subnet_id" {
  value = module.instructor_vnet.services_subnet_id
}

output "instructor_internal_subnet_id" {
  value = module.instructor_vnet.internal_subnet_id
}
output "instructor_fortigate_management_ip" {
  value = module.instructor_fortigate.management_public_ip
}
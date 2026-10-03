variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "vm_size" {
  type    = string
  default = "Standard_D4s_v7"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "transit_subnet_id" {
  type = string
}

variable "internal_subnet_id" {
  type = string
}

variable "management_subnet_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
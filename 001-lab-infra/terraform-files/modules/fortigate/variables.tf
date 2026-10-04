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

variable "port1_subnet_id" {
  type = string
}

variable "port2_subnet_id" {
  type = string
}

variable "port3_subnet_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_management_public_ip" {
  type    = bool
  default = false
}

variable "port1_ip" {
  type = string
}

variable "port2_ip" {
  type = string
}

variable "port3_ip" {
  type = string
}
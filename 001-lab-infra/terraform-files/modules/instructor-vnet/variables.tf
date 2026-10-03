variable "name" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "address_space" {
  type = string
}

variable "transit_subnet" {
  type = string
}

variable "management_subnet" {
  type = string
}

variable "services_subnet" {
  type = string
}

variable "internal_subnet" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "my_public_ip" {
  type = string
}
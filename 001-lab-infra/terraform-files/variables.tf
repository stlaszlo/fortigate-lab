variable "location" {
  type    = string
  default = "germanywestcentral"
}
variable "my_public_ip" {
  description = "Public IP allowed to manage the lab"
  type        = string
}
variable "instructor_admin_username" {
  type    = string
  default = "laciadmin"
}
variable "instructor_admin_password" {
  type      = string
  sensitive = true
}
variable "student_admin_password" {
  type      = string
  sensitive = true
}
variable "router_admin_username" {
  type    = string
  default = "routeradmin"
}

variable "router_admin_password" {
  type      = string
  sensitive = true
}
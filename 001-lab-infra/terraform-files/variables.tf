variable "fortigate_admin_password" {
  type      = string
  sensitive = true
}
variable "location" {
  type    = string
  default = "germanywestcentral"
}
variable "my_public_ip" {
  description = "Public IP allowed to manage the lab"
  type        = string
}


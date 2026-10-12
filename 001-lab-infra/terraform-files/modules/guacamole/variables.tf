variable "name" {
  description = "Name of the Guacamole VM."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the Guacamole VM."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the Guacamole VM NIC."
  type        = string
}

variable "private_ip" {
  description = "Static private IPv4 address for the Guacamole VM."
  type        = string
}

variable "vm_size" {
  description = "Azure VM size."
  type        = string
  default     = "Standard_B2s_v2"
}

variable "admin_username" {
  description = "Linux administrator username."
  type        = string
}

variable "admin_password" {
  description = "Linux administrator password."
  type        = string
  sensitive   = true
}

variable "guacamole_version" {
  description = "Apache Guacamole / guacd container version."
  type        = string
  default     = "1.6.0"
}

variable "guacamole_admin_password" {
  description = "Password assigned to the built-in guacadmin account."
  type        = string
  sensitive   = true
}

variable "database_password" {
  description = "Password for the Guacamole PostgreSQL database account."
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_token" {
  description = "Token for a remotely-managed Cloudflare Tunnel."
  type        = string
  sensitive   = true
}

variable "student_connections" {
  description = "Student Guacamole users and connection details for their lab pod."

  type = map(object({
    client_hostname    = string
    dmz_hostname       = string
    fortigate_hostname = string

    linux_username = string
    linux_password = string

    fortigate_username = string
    fortigate_password = string
  }))

  sensitive = true
}

variable "tags" {
  description = "Tags applied to the NIC and VM."
  type        = map(string)
  default     = {}
}

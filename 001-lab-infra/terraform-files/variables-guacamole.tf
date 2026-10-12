variable "guacamole_private_ip" {
  description = "Private IP of the Guacamole VM in snet-services."
  type        = string
  default     = "10.0.50.10"
}

variable "guacamole_vm_size" {
  description = "Azure VM SKU for the Guacamole host."
  type        = string
  default     = "Standard_B2s_v2"
}

variable "guacamole_vm_admin_username" {
  description = "Linux administrator username for the Guacamole VM."
  type        = string
  default     = "guacadminvm"
}

variable "guacamole_vm_admin_password" {
  description = "Linux administrator password for the Guacamole VM."
  type        = string
  sensitive   = true
}

variable "guacamole_version" {
  description = "Apache Guacamole container version."
  type        = string
  default     = "1.6.0"
}

variable "guacamole_admin_password" {
  description = "Password for Guacamole's built-in guacadmin account."
  type        = string
  sensitive   = true
}

variable "guacamole_database_password" {
  description = "Password for the Guacamole PostgreSQL account."
  type        = string
  sensitive   = true
}

variable "cloudflare_tunnel_token" {
  description = "Token for the remotely-managed Cloudflare Tunnel serving training.axionsec.ai."
  type        = string
  sensitive   = true
}

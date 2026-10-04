variable "name" {
  description = "Name of the Linux VM."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the VM."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the VM NIC."
  type        = string
}

variable "private_ip" {
  description = "Static private IPv4 address for the VM."
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

variable "role" {
  description = "VM role. Supported values: client, server, utility."
  type        = string

  validation {
    condition     = contains(["client", "server", "utility"], var.role)
    error_message = "role must be one of: client, server, utility."
  }
}

variable "extra_packages" {
  description = "Additional apt packages to install in addition to the role defaults."
  type        = list(string)
  default     = []
}

variable "extra_commands" {
  description = "Additional cloud-init runcmd entries."
  type        = list(string)
  default     = []
}

variable "motd" {
  description = "Optional MOTD. If null, a role-aware default is generated."
  type        = string
  default     = null
}

variable "accelerated_networking_enabled" {
  description = "Enable accelerated networking on the NIC."
  type        = bool
  default     = true
}

variable "ip_forwarding_enabled" {
  description = "Enable IP forwarding on the NIC."
  type        = bool
  default     = false
}

variable "os_disk_type" {
  description = "Managed disk storage type."
  type        = string
  default     = "Standard_LRS"
}

variable "tags" {
  description = "Tags applied to the NIC and VM."
  type        = map(string)
  default     = {}
}

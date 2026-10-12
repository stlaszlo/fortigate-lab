# Shared browser-access plane for the Fortinet training cohort.
#
# Cloudflare Tunnel publishes training.axionsec.ai to the Guacamole container.
# The Azure VM has no public IP and Guacamole itself does not expose a host port.

module "guacamole" {
  source = "./modules/guacamole"

  name                = "vm-guacamole-01"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  subnet_id  = module.instructor_network.subnet_ids["oob_management"]
  private_ip = var.guacamole_private_ip
  vm_size    = var.guacamole_vm_size

  admin_username = var.guacamole_vm_admin_username
  admin_password = var.guacamole_vm_admin_password

  guacamole_version        = var.guacamole_version
  guacamole_admin_password = var.guacamole_admin_password
  database_password        = var.guacamole_database_password
  cloudflare_tunnel_token  = var.cloudflare_tunnel_token

  student_connections = {
    for student, pod in local.student_pods : student => {
      client_hostname    = "client.s${pod.octet}.axionsec.internal"
      dmz_hostname       = "server.s${pod.octet}.axionsec.internal"
      fortigate_hostname = "fortigate-wan.s${pod.octet}.axionsec.internal"

      linux_username = pod.username
      linux_password = var.student_admin_password

      fortigate_username = pod.username
      fortigate_password = var.student_admin_password
    }
  }

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Guacamole_Access_Gateway"
    owner   = "Laszlo"
  }
}

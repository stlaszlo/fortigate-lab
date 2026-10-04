locals {
  role_packages = {
    client = [
      "curl",
      "dnsutils",
      "hping3",
      "iperf3",
      "iproute2",
      "jq",
      "net-tools",
      "netcat-openbsd",
      "nmap",
      "openssh-server",
      "tcpdump",
      "traceroute"
    ]

    server = [
      "curl",
      "nginx",
      "openssh-server",
      "python3",
      "python3-flask",
      "tcpdump"
    ]

    utility = [
      "curl",
      "dnsutils",
      "iproute2",
      "jq",
      "net-tools",
      "openssh-server",
      "tcpdump",
      "traceroute"
    ]
  }

  packages = distinct(concat(local.role_packages[var.role], var.extra_packages))

  default_motd = <<-EOT
    Fortinet Training Lab

    Host: ${var.name}
    Role: ${var.role}
    IP:   ${var.private_ip}
  EOT

  effective_motd = var.motd != null ? var.motd : local.default_motd

  role_commands = {
    client = [
      "systemctl enable --now ssh"
    ]

    server = [
      "systemctl enable --now ssh",
      "systemctl enable --now nginx"
    ]

    utility = [
      "systemctl enable --now ssh"
    ]
  }

  commands = concat(local.role_commands[var.role], var.extra_commands)
}

resource "azurerm_network_interface" "this" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  accelerated_networking_enabled = var.accelerated_networking_enabled
  ip_forwarding_enabled          = var.ip_forwarding_enabled

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.private_ip
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = var.name
  computer_name       = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size

  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.this.id
  ]

  custom_data = base64encode(<<-EOT
  #cloud-config
  ${yamlencode({
    hostname         = var.name
    manage_etc_hosts = true
    package_update   = true
    package_upgrade  = false

    packages = local.packages

    write_files = [
      {
        path        = "/etc/motd"
        owner       = "root:root"
        permissions = "0644"
        content     = local.effective_motd
      }
    ]

    runcmd = [
      for command in local.commands : ["sh", "-c", command]
    ]
})}
  EOT
)

os_disk {
  caching              = "ReadWrite"
  storage_account_type = var.os_disk_type
}

source_image_reference {
  publisher = "Canonical"
  offer     = "ubuntu-24_04-lts"
  sku       = "server"
  version   = "latest"
}

tags = var.tags
}

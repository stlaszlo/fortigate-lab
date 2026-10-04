# linux_server Terraform module

Generic Ubuntu Linux VM module for the Fortinet training lab.

## Roles

- `client` — troubleshooting and traffic-generation toolset
- `server` — nginx/SSH/Python/Flask baseline for DMZ services
- `utility` — lightweight general-purpose Linux VM

The module intentionally does **not** create public IPs, NSGs, route tables, or subnets.
Those remain responsibilities of the surrounding network architecture.

## Example: student client

```hcl
module "student01_client" {
  source = "./modules/linux_server"

  name                = "vm-student01-client"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  subnet_id  = module.student_network["student01"].subnet_ids["lan"]
  private_ip = "10.1.10.10"

  role = "client"

  admin_username = local.student_pods["student01"].username
  admin_password = var.student_admin_password

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Student_Client"
    Student = "student01"
    owner   = "Laszlo"
  }
}
```

## Example: student DMZ server

```hcl
module "student01_dmz" {
  source = "./modules/linux_server"

  name                = "vm-student01-dmz"
  location            = data.azurerm_resource_group.cohort.location
  resource_group_name = data.azurerm_resource_group.cohort.name

  subnet_id  = module.student_network["student01"].subnet_ids["dmz"]
  private_ip = "10.1.20.10"

  role = "server"

  admin_username = local.student_pods["student01"].username
  admin_password = var.student_admin_password

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Student_DMZ_Server"
    Student = "student01"
    owner   = "Laszlo"
  }
}
```

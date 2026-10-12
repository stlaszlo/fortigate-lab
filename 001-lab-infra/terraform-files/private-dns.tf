# -------------------------------------------------------------------
# Private DNS
# -------------------------------------------------------------------

resource "azurerm_private_dns_zone" "lab" {
  name                = "axionsec.internal"
  resource_group_name = data.azurerm_resource_group.cohort.name

  tags = {
    Cohort  = "fg_basic_advanced_121026"
    Purpose = "Fortinet_Training"
    Role    = "Instructor_Hub"
    owner   = "Laszlo"
  }
}


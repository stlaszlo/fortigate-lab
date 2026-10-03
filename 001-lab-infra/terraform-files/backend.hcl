resource_group_name  = "rg-forti-tfstate"
storage_account_name = "lsevstateserve"
container_name       = "tfstate"
key                  = "fortigate-lab.tfstate"

use_azuread_auth = true
use_cli          = true

tenant_id = "7acd9236-7e12-4ccd-b318-acd71d14d95f"
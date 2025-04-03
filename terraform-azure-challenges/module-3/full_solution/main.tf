provider "azurerm" {
  features {}
}

provider "tls" {}

module "bctf_vm" {
  source = "./modules/bctf_vm_module"

  location      = "westeurope"
  yourname      = "tdejong"
  my_ip_address = "45.94.174.33"
  additional_tags = {
    "MyTerraformSkillLevel" = "Uberhigh"
  }
  allowOfficeVPN = true
  enable_vm_shutdown = true
  vm_shutdown_time   = 2000
  data_disks = {
      1 = {
        name = "smalldatadisk"
        size = 128
      },
      2 = {
        name = "bigdatadisk"
        size = 256
      }
  }
}

moved {
  from = tls_private_key.bctf-ssh-key
  to   = module.bctf_vm.tls_private_key.bctf-ssh-key
}

moved {
  from = azurerm_resource_group.bctf-rg
  to   = module.bctf_vm.azurerm_resource_group.bctf-rg
}
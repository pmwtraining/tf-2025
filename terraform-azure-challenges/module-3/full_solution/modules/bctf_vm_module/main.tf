locals {
  #rootname         = "bctf-${var.yourname}-${var.location}"
  trimmed_rootname = replace(module.naming_convention.nameconv, "-", "")
  tags = merge({
    "costCenter" = "BrightCubesInternal"
    "owner"      = var.yourname
    "region"     = var.location
    }, var.additional_tags
  )
}

data "azurerm_client_config" "current" {}

module "naming_convention" {
  source = "../name_module"

  location = "westeurope"
  yourname = "tdejong"
}

resource "azurerm_resource_group" "bctf-rg" {
  name     = "${module.naming_convention.nameconv}-rg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "bctf-sa" {
  name                = "${local.trimmed_rootname}sa"
  resource_group_name = azurerm_resource_group.bctf-rg.name
  location            = var.location
  tags                = local.tags

  account_tier             = "Standard"
  account_replication_type = "LRS"
}

module "azure-vnet" {
  source = "Azure/vnet/azurerm"

  vnet_name           = "${module.naming_convention.nameconv}-vnet"
  resource_group_name = azurerm_resource_group.bctf-rg.name
  address_space       = ["10.1.0.0/16"]
  subnet_prefixes     = ["10.1.90.0/24", "10.1.100.0/24"]
  subnet_names        = ["subnet1", "subnet2"]
  use_for_each        = true
  vnet_location       = var.location

  subnet_service_endpoints = {
    subnet1 = ["Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault"]
    subnet2 = ["Microsoft.KeyVault"]
  }

  nsg_ids = {
    subnet1 = azurerm_network_security_group.bctf-nsg.id
    subnet2 = azurerm_network_security_group.bctf-nsg.id
  }

  tags = local.tags
}

resource "azurerm_public_ip" "bctf-pip" {
  name                = "${module.naming_convention.nameconv}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.bctf-rg.name
  allocation_method   = "Dynamic"
  tags                = local.tags
}

resource "azurerm_network_interface" "bctf-nic" {
  name                = "${module.naming_convention.nameconv}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.bctf-rg.name
  tags                = local.tags

  ip_configuration {
    name                          = "${module.naming_convention.nameconv}-nic-cfg"
    subnet_id                     = module.azure-vnet.vnet_subnets[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bctf-pip.id
  }
}

resource "azurerm_network_security_group" "bctf-nsg" {
  name                = "${module.naming_convention.nameconv}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.bctf-rg.name
  tags                = local.tags
}

# resource "azurerm_subnet_network_security_group_association" "bctf-nsg_to_subnet" {
#   subnet_id                 = azurerm_subnet.bctf-subnet.id
#   network_security_group_id = azurerm_network_security_group.bctf-nsg.id
# }

resource "azurerm_network_security_rule" "ssh-access" {
  name                        = "Allow-SSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.my_ip_address # Your own IP address
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.bctf-rg.name
  network_security_group_name = azurerm_network_security_group.bctf-nsg.name
}

resource "azurerm_network_security_rule" "vre-allow_office_vpn" {
  count                       = var.allowOfficeVPN ? 1 : 0
  name                        = "Allow-Office_VPN"
  priority                    = 800
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = ["145.109.0.0/17", "145.18.0.0/16", "146.50.0.0/16"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.bctf-rg.name
  network_security_group_name = azurerm_network_security_group.bctf-nsg.name
}

resource "azurerm_key_vault" "bctf-kv" {
  name                = "${local.trimmed_rootname}-kv"
  location            = var.location
  resource_group_name = azurerm_resource_group.bctf-rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = local.tags

  enable_rbac_authorization  = false
  soft_delete_retention_days = 10

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = module.azure-vnet.vnet_subnets
    ip_rules                   = ["${var.my_ip_address}"] # Your own IP address
  }
}

resource "azurerm_key_vault_access_policy" "bctf-kv-current-ap" {
  key_vault_id       = azurerm_key_vault.bctf-kv.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = data.azurerm_client_config.current.object_id
  secret_permissions = ["Get", "Set", "List", "Delete", "Purge", ]
}

resource "azurerm_key_vault_access_policy" "bctf-kv-vm-ap" {
  key_vault_id       = azurerm_key_vault.bctf-kv.id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  object_id          = azurerm_linux_virtual_machine.bctf-vm.identity[0].principal_id
  secret_permissions = ["Get", "Set", "List", "Delete", "Purge", ]
}

resource "tls_private_key" "bctf-ssh-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_key_vault_secret" "bctf-private-key" {
  name            = "private-key-openssh"
  value           = tls_private_key.bctf-ssh-key.private_key_openssh
  key_vault_id    = azurerm_key_vault.bctf-kv.id
  expiration_date = "2022-12-31T00:00:00Z"
  content_type    = "openssh private key"

  depends_on = [
    azurerm_key_vault_access_policy.bctf-kv-current-ap
  ]
}

resource "azurerm_key_vault_secret" "bctf-public-key" {
  name            = "public-key-openssh"
  value           = tls_private_key.bctf-ssh-key.public_key_openssh
  key_vault_id    = azurerm_key_vault.bctf-kv.id
  expiration_date = "2022-12-31T00:00:00Z"
  content_type    = "openssh public key"

  depends_on = [
    azurerm_key_vault_access_policy.bctf-kv-current-ap
  ]
}

resource "azurerm_linux_virtual_machine" "bctf-vm" {
  name                  = "${module.naming_convention.nameconv}-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.bctf-rg.name
  size                  = var.vm_size
  network_interface_ids = [azurerm_network_interface.bctf-nic.id]
  admin_username        = var.yourname
  computer_name         = local.trimmed_rootname

  tags = merge(
    local.tags,
    { "enable_vm_shutdown" = tostring(var.enable_vm_shutdown) },
    { "vm_shutdown_time" = tostring(var.vm_shutdown_time) }
  )

  admin_ssh_key {
    username   = var.yourname
    public_key = azurerm_key_vault_secret.bctf-public-key.value
  }
  disable_password_authentication = true

  # admin_password = "ThisWasSuchACoolWorkshop!1!"
  # disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_sku
    disk_size_gb         = var.os_disk_size
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.bctf-sa.primary_blob_endpoint
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "bctf-vm-shutdown" {
  virtual_machine_id = azurerm_linux_virtual_machine.bctf-vm.id
  location           = var.location
  enabled            = var.enable_vm_shutdown

  daily_recurrence_time = var.vm_shutdown_time
  timezone              = "W. Europe Standard Time"

  notification_settings {
    enabled = false
  }
}

resource "azurerm_managed_disk" "bctf-vm-datadisk" {
  for_each = var.data_disks
  
  name                 = each.value.name
  location             = var.location
  resource_group_name  = azurerm_resource_group.bctf-rg.name
  storage_account_type = "Standard_LRS"
  disk_size_gb         = each.value.size
  create_option        = "Empty"
}

resource "azurerm_virtual_machine_data_disk_attachment" "bctf-vm-datadisk-attach" {
  for_each = var.data_disks
  
  managed_disk_id    = azurerm_managed_disk.bctf-vm-datadisk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.bctf-vm.id
  lun                = 10 + each.key
  caching            = "ReadWrite"
}
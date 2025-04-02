#lab1.9

output "ip_address" {

  value = azurerm_container_group.basics-yourName.ip_address

}

output "fqdn" {

  value = "http://${azurerm_container_group.basics-yourName.fqdn}"
}

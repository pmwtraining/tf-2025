output "ip_address" {
  #  value = azurerm_container_group.example-yourName.ip_address

  value = azurerm_container_group.basics-yourName.ip_address

}

output "fqdn" {
  #  value = "http://${azurerm_container_group.example-yourName.fqdn}"

  value = "http://${azurerm_container_group.basics-yourName.fqdn}"
}

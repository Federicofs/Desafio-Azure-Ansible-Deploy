output "vm_user" {
  value = azurerm_linux_virtual_machine.vm_1.admin_username
}
output "pip_vm" {
  value = azurerm_linux_virtual_machine.vm_1.public_ip_addresses
}


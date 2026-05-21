output "public_vm_url" {
  value = "http://${azurerm_public_ip.pub_vm_ip.ip_address}"
}

output "private_vm_lb_url" {
  value = "http://${azurerm_public_ip.lb_ip.ip_address}"
}
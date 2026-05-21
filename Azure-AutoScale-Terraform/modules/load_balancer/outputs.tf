output "lb_id" {
  value = azurerm_lb.this.id
}

output "backend_pool_id" {
  value = azurerm_lb_backend_address_pool.this.id
}

output "public_ip" {
  value = azurerm_public_ip.lb_ip.ip_address
}
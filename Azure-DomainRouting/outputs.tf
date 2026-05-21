output "appgw_public_ip" {
  value = module.app_gateway.public_ip
}

output "organic_url" {
  value = "http://${var.organic_domain}"
}

output "fitness_url" {
  value = "http://${var.fitness_domain}"
}

output "organic_vm_private_ip" {
  value = module.organic_vm.private_ip
}

output "fitness_vm_private_ip" {
  value = module.fitness_vm.private_ip
}
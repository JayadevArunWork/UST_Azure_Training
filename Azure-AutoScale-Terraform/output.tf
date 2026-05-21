output "app_url" {
  value = "http://${module.lb.public_ip}"
}

output "lb_public_ip" {
  value = module.lb.public_ip
}

output "vmss_id" {
  value = module.vmss.vmss_id
}
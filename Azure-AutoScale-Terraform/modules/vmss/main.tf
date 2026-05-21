resource "azurerm_linux_virtual_machine_scale_set" "this" {
  name                            = var.vmss_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  sku                             = var.vmss_sku
  instances                       = var.vmss_instances
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  overprovision                   = false
  upgrade_mode                    = "Automatic"
  single_placement_group          = false

  custom_data = base64encode(file("${path.module}/custom_data.sh"))

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "StandardSSD_LRS"
    caching              = "ReadWrite"
    disk_size_gb         = 30
  }

  network_interface {
    name                      = "${var.vmss_name}-nic"
    primary                   = true
    network_security_group_id = var.nsg_id

    ip_configuration {
      name                                  = "${var.vmss_name}-ipconfig"
      primary                               = true
      subnet_id                             = var.subnet_id
      load_balancer_backend_address_pool_ids = [var.lb_backend_pool_id]
    }
  }

  # Health check for auto repair
  extension {
    name                       = "HealthExtension"
    publisher                  = "Microsoft.ManagedServices"
    type                       = "ApplicationHealthLinux"
    type_handler_version       = "1.0"
    auto_upgrade_minor_version = true
    settings = jsonencode({
      protocol    = "http"
      port        = 80
      requestPath = "/"
    })
  }

  automatic_instance_repair {
    enabled      = true
    grace_period = "PT10M"
  }

  # Ignore instance count changes by autoscale
  lifecycle {
    ignore_changes = [instances]
  }
}
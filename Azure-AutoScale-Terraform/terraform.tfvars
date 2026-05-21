location            = "Central India"
resource_group_name = "organic-ghee-rg"

# Network
vnet_name          = "ghee-vnet"
vnet_address_space = ["10.0.0.0/16"]
subnet_name        = "ghee-subnet"
subnet_prefix      = ["10.0.1.0/24"]
nsg_name           = "ghee-nsg"
nat_gw_name        = "ghee-nat-gw"

# Load Balancer
lb_name = "ghee-lb"

# VMSS - 2 CPU, 4GB RAM, 30GB Disk
vmss_name           = "ghee-vmss"
vmss_sku            = "Standard_B2ats_v2"
vmss_instances      = 1
vmss_admin_username = "jayadevazure"
vmss_admin_password = "JDkittu#2003AZ"

# Autoscale
autoscale_min = 1
autoscale_max = 2
scale_out_cpu = 70
scale_in_cpu  = 25

# Service Bus
servicebus_name   = "ghee-servicebus"
topic_name        = "traffic-alerts"
subscription_name = "email-sub"

# Monitor
alert_email = "jayadevarun03@gmail.com"

# Logic App
logic_app_name = "ghee-logic-app"
terraform {
  required_providers {
    azurerm = {
        source  = "hashicorp/azurerm"
        version = "3.0.0"
      }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.name_rg
  location = var.location
}

#Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.name_net
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.2.0.0/20"]

  tags = {
    env = "dev"
  }
}
#Subnet for database
resource "azurerm_subnet" "subnet-1" {
  name                 = var.name_subnet_1
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.2.1.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}
#Subnet 
resource "azurerm_subnet" "subnet-2" {
  name                 = var.name_subnet_2
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.2.2.0/24"]
  
}

#ip public 
resource "azurerm_public_ip" "lb_pip" {
  name                = var.name_public_lb
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku = "Standard"
}
resource "azurerm_public_ip" "vm_pip" {
  name                = var.name_public_vm
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}


resource "azurerm_availability_set" "set-1" {
  name                = var.name_set
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}


#Interface virtual machine 
resource "azurerm_network_interface" "vm-nic" {
  depends_on=[azurerm_resource_group.rg]
  name                = var.name_nic
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnet-2.id   
    public_ip_address_id          = azurerm_public_ip.vm_pip.id   
  }
}
# Las nic de la 2 VM falta saber como crear 3 claves de ssh
# resource "azurerm_network_interface" "vm-nic-2" {
#   depends_on=[azurerm_resource_group.rg]
#   name                = "vm-nic-2"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name

#   ip_configuration {
#     name                          = "internal"
#     private_ip_address_allocation = "Dynamic"
#     subnet_id                     = azurerm_subnet.subnet-2.id   
#     public_ip_address_id          = azurerm_public_ip.vm_pip.id   
#   }
# }
# resource "azurerm_network_interface" "vm-nic-3" {
#   depends_on=[azurerm_resource_group.rg]
#   name                = "vm-nic-3"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name

#   ip_configuration {
#     name                          = "internal"
#     private_ip_address_allocation = "Dynamic"
#     subnet_id                     = azurerm_subnet.subnet-2.id   
#     public_ip_address_id          = azurerm_public_ip.vm_pip.id   
#   }
# }

#SSH 
resource "tls_private_key" "linux_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "local_file" "linuxkey" {
  filename = var.file_ssh_name
  content = tls_private_key.linux_key.private_key_pem 
}

#Virtual machine 
resource "azurerm_linux_virtual_machine" "vm_1" {
  name                  = var.name_vm
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.vm-nic.id]
  size                  = var.size
  admin_username        = var.user_admin

  availability_set_id = azurerm_availability_set.set-1.id
    
  admin_ssh_key {
     username   = var.user_admin
     public_key = tls_private_key.linux_key.public_key_openssh
   }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  depends_on = [
    azurerm_network_interface.vm-nic,
    tls_private_key.linux_key
    ]
}

resource "azurerm_lb" "lb_pip" {
  name                = var.name_load
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
  sku = "Standard"
  depends_on = [ azurerm_public_ip.lb_pip ]
}

resource "azurerm_lb_backend_address_pool" "Pool-1" {
  loadbalancer_id = azurerm_lb.lb_pip.id

  name            = var.name_address_pool_1
  depends_on      = [ azurerm_lb.lb_pip, azurerm_availability_set.set-1 ]
}

resource "azurerm_lb_backend_address_pool_address" "vm_1" {
  name                    = var.name_addr_pool_addr
  backend_address_pool_id = azurerm_lb_backend_address_pool.Pool-1.id
  virtual_network_id      = azurerm_virtual_network.vnet.id
  ip_address              = azurerm_network_interface.vm-nic.private_ip_address
  depends_on = [ azurerm_lb_backend_address_pool.Pool-1 ]
}


resource "azurerm_lb_probe" "probe-1" {
  
  loadbalancer_id = azurerm_lb.lb_pip.id
  name            = var.name_probe
  port            = 80
  depends_on = [ azurerm_lb.lb_pip ]
}

resource "azurerm_lb_rule" "Rule_80" {
  loadbalancer_id                = azurerm_lb.lb_pip.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.Pool-1.id ]
  probe_id = azurerm_lb_probe.probe-1.id
  depends_on = [ azurerm_lb.lb_pip , azurerm_lb_probe.probe-1 ]
}
#database

#Enables you to manage Private DNS zones within Azure DNS
# resource "azurerm_private_dns_zone" "default" {
#   name                = "federico.mysql.database.azure.com"
#   resource_group_name = azurerm_resource_group.rg.name
# }

# # Enables you to manage Private DNS zone Virtual Network Links
# resource "azurerm_private_dns_zone_virtual_network_link" "default" {
#   name                  = "mysqlfsVnetZonefederico.com"
#   private_dns_zone_name = azurerm_private_dns_zone.default.name
#   resource_group_name   = azurerm_resource_group.rg.name
#   virtual_network_id    = azurerm_virtual_network.vnet.id
# }

# # Manages the MySQL Flexible Server
# resource "azurerm_mysql_flexible_server" "default" {
#   location                     = azurerm_resource_group.rg.location
#   resource_group_name          = azurerm_resource_group.rg.name
#   name                         = "mysqlfs-federico"
#   administrator_login          = "fedeAdmin"
#   administrator_password       = "rAndon471"
#   backup_retention_days        = 7
#   delegated_subnet_id          = azurerm_subnet.subnet-1.id
#   private_dns_zone_id          = azurerm_private_dns_zone.default.id
#   sku_name                     = "B_Standard_B1s"
#   version                      = "5.7"
  
#   storage {
#     iops    = 400
#     size_gb = 32
#   }

#   depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
# }

# resource "azurerm_mysql_flexible_database" "example" {
#   name                = "exampledb"
#   resource_group_name = azurerm_resource_group.rg.name
#   server_name         = azurerm_mysql_flexible_server.default.name
#   charset             = "utf8"
#   collation           = "utf8_unicode_ci"
# }



#Security group
resource "azurerm_network_security_group" "vm-nsg" {
  depends_on=[azurerm_resource_group.rg]
  name                = var.name_security_group
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  
  security_rule {
    name                       = "AllowHTTP"
    description                = "Allow HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "AllowSSH"
    description                = "Allow SSH"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
 }

 resource "azurerm_subnet_network_security_group_association" "nsg-association" {
   depends_on=[azurerm_resource_group.rg]
   subnet_id                 = azurerm_subnet.subnet-2.id
   network_security_group_id = azurerm_network_security_group.vm-nsg.id
 }
#------------------------------------------------------------------------------------------------------------------------------------------
# usar ${var.name_vm}-1
# Virtual machine 
# resource "azurerm_linux_virtual_machine" "vm_2" {
#   name                  = var.name_vm
#   location              = azurerm_resource_group.rg.location
#   resource_group_name   = azurerm_resource_group.rg.name
#   network_interface_ids = [azurerm_network_interface.vm-nic.id]
#   size                  = var.size
#   admin_username        = var.user_admin

#   availability_set_id = azurerm_availability_set.set-1.id
    
#   admin_ssh_key {
#      username   = var.user_admin
#      public_key = tls_private_key.linux_key.public_key_openssh
#    }
  
#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   depends_on = [
#     azurerm_network_interface.vm-nic,
#     tls_private_key.linux_key
#     ]
# }
#Virtual machine 
# resource "azurerm_linux_virtual_machine" "vm_3" {
#   name                  = var.name_vm
#   location              = azurerm_resource_group.rg.location
#   resource_group_name   = azurerm_resource_group.rg.name
#   network_interface_ids = [azurerm_network_interface.vm-nic.id]
#   size                  = var.size
#   admin_username        = var.user_admin

#   availability_set_id = azurerm_availability_set.set-1.id
    
#   admin_ssh_key {
#      username   = var.user_admin
#      public_key = tls_private_key.linux_key.public_key_openssh
#    }
  
#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   depends_on = [
#     azurerm_network_interface.vm-nic,
#     tls_private_key.linux_key
#     ]
# }
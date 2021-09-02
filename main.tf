terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}


data "azurerm_resource_group" "rg" {
  name = "int4"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}



resource "local_file" "private_key_file" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "id_rsa"
}


resource "azurerm_virtual_network" "publicvent" {
  name                = "public-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "publicsubnet" {
  name                 = "public-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.publicvent.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "publicvmip" {
  name                = "public-vm-ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

resource "azurerm_network_interface" "publicvmnic" {
  name                = "public-vm-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.publicsubnet.id
    private_ip_address_allocation = azurerm_public_ip.publicvmip.allocation_method
    public_ip_address_id          = azurerm_public_ip.publicvmip.id
  }

}

resource "azurerm_windows_virtual_machine" "publicvm" {
  name                  = "public-vm"
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.publicvmnic.id]
  size                  = "Standard_D2s_v3"

  admin_username = "adminuser"
  admin_password = "P@ssword123!@#"

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

resource "azurerm_virtual_network" "privatevnet" {
  name                = "private-vnet"
  address_space       = ["192.168.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "privatesubnet" {
  name                 = "private-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.privatevnet.name
  address_prefixes     = ["192.168.1.0/24"]
}

resource "azurerm_network_interface" "privatevmnic" {
  name                = "private-vm-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig2"
    subnet_id                     = azurerm_subnet.privatesubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "privatevm" {
  name                = "private-vm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = var.instance_size

  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.privatevmnic.id]

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_virtual_network_peering" "public2private" {
  name                      = "peer-public-to-private"
  resource_group_name       = data.azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.publicvent.name
  remote_virtual_network_id = azurerm_virtual_network.privatevnet.id

}

resource "azurerm_virtual_network_peering" "private2public" {
  name                      = "peer-private-to-public"
  resource_group_name       = data.azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.privatevnet.name
  remote_virtual_network_id = azurerm_virtual_network.publicvent.id
}

resource "azurerm_network_security_group" "securitygroup" {
  name                = "security-group"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "disable-internet-access"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

}

resource "azurerm_subnet_network_security_group_association" "privatesg" {
  subnet_id                 = azurerm_subnet.privatesubnet.id
  network_security_group_id = azurerm_network_security_group.securitygroup.id
}
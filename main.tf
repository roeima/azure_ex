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

# Create ssh key for the linux machine
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key in id_rsa file
resource "local_file" "private_key_file" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "id_rsa"
}

# Create Virtual network for windows vm
resource "azurerm_virtual_network" "public_vnet" {
  name                = "public-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Create subnet for windows vm
resource "azurerm_subnet" "public_subnet" {
  name                 = "public-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.public_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public ip for windows vm
resource "azurerm_public_ip" "public_vm_ip" {
  name                = "public-vm-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
}

# Create Network Card for windows vm
resource "azurerm_network_interface" "public_vm_nic" {
  name                = "public-vm-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "public-vm-ipconfig"
    subnet_id                     = azurerm_subnet.public_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_vm_ip.id
  }

}

# Create Windows VM with public ip
resource "azurerm_windows_virtual_machine" "public_vm" {
  name                  = "public-vm"
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.public_vm_nic.id]
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

# Create Virtual network for linux vm
resource "azurerm_virtual_network" "private_vnet" {
  name                = "private-vnet"
  address_space       = ["192.168.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

# Create subnet for linux vm
resource "azurerm_subnet" "private_subnet" {
  name                 = "private-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.private_vnet.name
  address_prefixes     = ["192.168.1.0/24"]
}

# Create Network Card for linux vm
resource "azurerm_network_interface" "private_vm_nic" {
  name                = "private-vm-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "private-vm-ipconfig"
    subnet_id                     = azurerm_subnet.private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Create Linux VM
resource "azurerm_linux_virtual_machine" "private_vm" {
  name                = "private-vm"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.instance_size

  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.private_vm_nic.id]

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

# Create Peer for the public net to the private net
resource "azurerm_virtual_network_peering" "public_2_private" {
  name                      = "peer-public-to-private"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.public_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.private_vnet.id

}

# Create Peer for the private net to the public net
resource "azurerm_virtual_network_peering" "private_2_public" {
  name                      = "peer-private-to-public"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.private_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.public_vnet.id
}


# Disable internet access from the linux vm
resource "azurerm_network_security_group" "security_group" {
  name                = "security-group"
  location            = var.location
  resource_group_name = var.resource_group_name

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

# Attach Security Group to the linux vm subnet
resource "azurerm_subnet_network_security_group_association" "private_security_group" {
  subnet_id                 = azurerm_subnet.private_subnet.id
  network_security_group_id = azurerm_network_security_group.security_group.id
}
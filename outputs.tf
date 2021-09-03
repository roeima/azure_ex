output "tls_private_key" {
    description = "Linux machine private key"
    value     = tls_private_key.ssh_key.private_key_pem
    sensitive = true
}

output "window_public_ip" {
    description = "Windows machine public ip"
    value = azurerm_windows_virtual_machine.publicvm.public_ip_address
  
}
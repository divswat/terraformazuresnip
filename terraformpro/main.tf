provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "dv" {
  name     = "terrazure"
  location = "westindia"
}

resource "azurerm_virtual_network" "azurnet" {
  name                = "azurnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.dv.location
  resource_group_name = azurerm_resource_group.dv.name
}

resource "azurerm_subnet" "subi" {
  name                 = "subi"
  resource_group_name  = azurerm_resource_group.dv.name
  virtual_network_name = azurerm_virtual_network.azurnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nicaz" {
  name                = "nicaz"
  location            = azurerm_resource_group.dv.location
  resource_group_name = azurerm_resource_group.dv.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subi.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "azuvm" {
  name                = "azuvm"
  location            = azurerm_resource_group.dv.location
  resource_group_name = azurerm_resource_group.dv.name
  network_interface_ids = [azurerm_network_interface.nicaz.id]

  size = "Standard_DS2_v2"

  admin_username = "adminuser"
  admin_password = "Password1234!"  

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  provisioner "file" {
    source      = ""
    destination = "/var/www/html/snipe-it/.env"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y apache2 mariadb-server mariadb-client",
      "sudo systemctl start apache2",
      "sudo systemctl enable apache2",
      "sudo systemctl start mysql",
      "sudo systemctl enable mysql",
      "mysql -u root -e 'CREATE DATABASE snipeit;'",
      "mysql -u root -e \"GRANT ALL PRIVILEGES ON snipeit.* TO 'snipeit'@'10.0.0.0/16 IDENTIFIED BY 'Password1234!';\"",
      "sudo apt-get install -y php libapache2-mod-php php-mysql php-curl php-json php-gd php-mcrypt php-zip php-mbstring",
      "sudo systemctl restart apache2",
      "sudo apt-get install -y git",
      "cd /var/www/html",
      "sudo git clone https://github.com/snipe/snipe-it .",
      "sudo chmod 777 storage",
      "sudo chmod 777 bootstrap",
      "composer install --no-dev --prefer-source",
      "php artisan key:generate",
      "php artisan migrate --seed"
    ]
  }

  tags = {
    environment = "testing"
  }
}

resource "azurerm_network_security_group" "ANG" {
  name                = "ANG"
  location            = azurerm_resource_group.dv.location
  resource_group_name = azurerm_resource_group.dv.name
}

resource "azurerm_network_security_rule" "ANS" {
  name                        = "ANS"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.dv.name
  network_security_group_name = azurerm_network_security_group.ANG.name
}

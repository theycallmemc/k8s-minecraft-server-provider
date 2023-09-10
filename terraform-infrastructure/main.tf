resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Create virtual network
resource "azurerm_virtual_network" "terraform_network" {
  name                = "Vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "terraform_subnet" {
  name                 = "Subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs (only one is needed)
resource "azurerm_public_ip" "public_ip" {
  name                = "PublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "terraform_nsg" {
  name                = "NetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1002  # You can adjust the priority as needed to control rule evaluation order
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate public IP with network interface of virtual machine
resource "azurerm_network_interface" "terraform_nic" {
  count               = 1 
  name                = "NIC1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "nic_configuration1"
    subnet_id                     = azurerm_subnet.terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Generate random text for unique storage account name
resource "random_id" "random_id" {
  count = 1  

  keepers = {
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "storage_account" {
  count                   = 1 
  name                    = "diag${random_id.random_id[0].hex}"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  account_tier            = "Standard"
  account_replication_type = "LRS"
}

# creating cloud init script
data "template_cloudinit_config" "vm" {
  gzip          = true
  base64_encode = true

 part {
    content_type = "text/cloud-config"
    content = <<EOF
    package_update: true
    package_upgrade: true
    packages:
      - python3
      - python3-pip
      - docker.io
      - git
    EOF
  }

  part {
  content_type = "text/cloud-config"
  content = <<EOF
    runcmd:
      - cd
      - date +"%T.%N"
      - echo "Start cloud init"
      - mkdir /tmp/workspace
      - cd /tmp/workspace
      - date +"%T.%N"
      - echo "Clone repo"
      - git clone https://github.com/fl028/k8s-minecraft-server-provider.git
      - pip install -r /tmp/workspace/k8s-minecraft-server-provider/k8s-operator/requirements.txt
      - date +"%T.%N"
      - echo "Start k3s installation"
      - ufw disable
      - curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode=644
      - date +"%T.%N"
      - echo "Sleeping - k3s installation"
      - sleep 80
      - date +"%T.%N"
      - cp /tmp/workspace/k8s-minecraft-server-provider/k8s-operator/registries.yaml /etc/rancher/k3s/registries.yaml
      - sudo systemctl restart k3s
      - date +"%T.%N"
      - echo "Sleeping - k3s restart"
      - sleep 80
      - date +"%T.%N"
      - echo "Cube config"
      - mkdir /root/.kube
      - cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
      - export KUBECONFIG=/root/.kube/config
      - date +"%T.%N"
      - echo "Docker setup"
      - docker run -d -p 5000:5000 --restart=always --name registry registry:2
      - date +"%T.%N"
      - echo "Building operator"
      - cd /tmp/workspace/k8s-minecraft-server-provider/k8s-operator
      - docker build -t minecraft-operator-image .
      - docker tag minecraft-operator-image localhost:5000/minecraft-operator-image
      - docker push localhost:5000/minecraft-operator-image
      - kubectl apply -f operator-deployment.yaml
      - date +"%T.%N"
      - echo "Verify - docker and kube pods"
      - sleep 6
      - date +"%T.%N"
      - docker ps
      - kubectl get pods,services -A -o wide
      - date +"%T.%N"
      - echo "Done"
    EOF
  }
}

# Create virtual machine (only one is needed)
resource "azurerm_linux_virtual_machine" "terraform_vm" {
  count                  = 1 
  name                   = "vm1"
  location               = azurerm_resource_group.rg.location
  resource_group_name    = azurerm_resource_group.rg.name
  network_interface_ids  = [azurerm_network_interface.terraform_nic[0].id]  # Use the first network interface
  size                   = "Standard_B2s"

  custom_data = data.template_cloudinit_config.vm.rendered 

  computer_name  = "vm1"
  admin_username = var.username

  os_disk {
    name                 = "osdisk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  admin_ssh_key {
    username   = var.username
    public_key = jsondecode(azapi_resource_action.ssh_public_key_gen.output).publicKey
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage_account[0].primary_blob_endpoint  # Use the storage account for the first VM
  }
}

# Output variables to display the SSH command and IP
output "ssh_command_vm1"{
  value = "ssh -i ./private_key.pem azureadmin@${azurerm_public_ip.public_ip.ip_address}"
}

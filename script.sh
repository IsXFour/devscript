#!/bin/bash
set -e

# Function to wait for apt locks
wait_for_apt() {
  while fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "Waiting for other apt/dpkg processes to complete..."
    sleep 5
  done
}

# Wait for any existing apt processes to finish
wait_for_apt

# Update package lists
apt-get update

# Install prerequisites
apt-get install -y gnupg software-properties-common curl apt-transport-https ca-certificates

# Install HashiCorp GPG key
wait_for_apt
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null

# Add HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

# Update again after adding repository
wait_for_apt
apt-get update

# Install Terraform
wait_for_apt
apt-get install -y terraform

# Install Azure CLI
wait_for_apt
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Verify installations
echo "Terraform version:"
terraform --version
echo "Azure CLI version:"
az --version
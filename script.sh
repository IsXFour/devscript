#!/bin/bash
set -e

echo "Starting installation script..."

# Function to wait for apt locks with a timeout
wait_for_apt() {
  local timeout=300  # 5 minutes timeout
  local start_time=$(date +%s)
  local waited=0
  
  echo "Checking for apt/dpkg locks..."
  
  while true; do
    if ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1 && 
       ! fuser /var/lib/dpkg/lock >/dev/null 2>&1 && 
       ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
      echo "No locks detected, proceeding."
      return 0
    fi
    
    # Calculate elapsed time
    local current_time=$(date +%s)
    local elapsed=$((current_time - start_time))
    
    # Check timeout
    if [ $elapsed -gt $timeout ]; then
      echo "Timeout waiting for locks. Attempting to kill apt processes..."
      ps aux | grep -i apt | grep -v grep
      killall apt apt-get dpkg 2>/dev/null || true
      sleep 2
      rm -f /var/lib/apt/lists/lock 2>/dev/null
      rm -f /var/lib/dpkg/lock 2>/dev/null
      rm -f /var/lib/dpkg/lock-frontend 2>/dev/null
      return 0
    fi
    
    # Print status every 15 seconds
    if [ $((elapsed % 15)) -eq 0 ] && [ $waited -ne $elapsed ]; then
      waited=$elapsed
      echo "Waiting for other apt/dpkg processes to complete... ($elapsed seconds elapsed)"
      ps aux | grep -E 'apt|dpkg' | grep -v grep || echo "No apt/dpkg processes found, but locks exist"
    fi
    
    sleep 1
  done
}

# Setup catchable exits
trap 'echo "Script interrupted or failed. Cleaning locks..."; rm -f /var/lib/apt/lists/lock; rm -f /var/lib/dpkg/lock; rm -f /var/lib/dpkg/lock-frontend;' EXIT

echo "Initial wait for apt locks..."
wait_for_apt

echo "Updating package lists..."
apt-get update -q || { echo "Failed to update package lists"; exit 1; }

echo "Installing prerequisites..."
apt-get install -y gnupg software-properties-common curl apt-transport-https ca-certificates

echo "Adding HashiCorp GPG key..."
wait_for_apt
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null

echo "Adding HashiCorp repository..."
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list

echo "Updating package lists after adding repository..."
wait_for_apt
apt-get update -q

echo "Installing Terraform..."
wait_for_apt
apt-get install -y terraform

echo "Installing Azure CLI..."
wait_for_apt
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

echo "Verifying installations..."
terraform --version || echo "Terraform not properly installed"
az --version || echo "Azure CLI not properly installed"

echo "Installation completed successfully."
exit 0
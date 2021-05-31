#!/bin/bash

curl -s -m 2 -X POST -H "Content-Type: application/json" -d "{ \"thedog\": \"starting\" }" http://10.0.0.21:25801/48

# Update system
printf 'Updating system\n'
sudo apt update -y
sudo apt dist-upgrade -y
printf 'Update complete\n'

# Install Node
printf 'Checking Node.js\n'
if ! type node > /dev/null 2>&1; 
then
  curl -sL https://deb.nodesource.com/setup_10.x | sudo bash -
  sudo apt install -y nodejs
fi
printf "Node $(node -v) installed\n"
printf "NPM $(npm -v) installed\n"

# Install Snap
printf 'Checking Snap\n'
if ! type snap > /dev/null 2>&1; 
then
  sudo apt install -y snapd
  printf "Installing core...\n"
  sudo snap install core
fi
printf "Updating core...\n"
sudo snap refresh core

# Install VSCode
bash <(curl -fsSL https://code-server.dev/install.sh)

# Create service to run VSCode at startup
serviceName="vscode"
serviceFile="/lib/systemd/system/$serviceName.service"

sudo rm -f $serviceFile
sudo touch $serviceFile
echo '[Unit]' | sudo tee -a $serviceFile > /dev/null
echo 'Description=VSCode' | sudo tee -a $serviceFile > /dev/null
echo 'After=network-online.target' | sudo tee -a $serviceFile > /dev/null
echo '' | sudo tee -a $serviceFile > /dev/null
echo '[Service]' | sudo tee -a $serviceFile > /dev/null
echo 'Type=simple' | sudo tee -a $serviceFile > /dev/null
echo 'User=root' | sudo tee -a $serviceFile > /dev/null
echo "ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:22193 --auth none" | sudo tee -a $serviceFile > /dev/null
echo 'Restart=always' | sudo tee -a $serviceFile > /dev/null
echo 'RestartSec=5' | sudo tee -a $serviceFile > /dev/null
echo 'StandardOutput=syslog' | sudo tee -a $serviceFile > /dev/null
echo 'StandardError=syslog' | sudo tee -a $serviceFile > /dev/null
echo "SyslogIdentifier=$serviceName" | sudo tee -a $serviceFile > /dev/null
echo '' | sudo tee -a $serviceFile > /dev/null
echo '[Install]' | sudo tee -a $serviceFile > /dev/null
echo 'WantedBy=multi-user.target' | sudo tee -a $serviceFile > /dev/null

sudo rm -f "/etc/systemd/system/multi-user.target.wants/$serviceName.service"
sudo ln -s "$serviceFile" "/etc/systemd/system/multi-user.target.wants/$serviceName.service"
sudo systemctl enable $serviceName
sudo systemctl start $serviceName
printf "$serviceName service enabled\n"

curl -s -m 2 -X POST -H "Content-Type: application/json" -d "{ \"thedog\": \"complete\" }" http://10.0.0.21:25801/48
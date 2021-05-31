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

curl -s -m 2 -X POST -H "Content-Type: application/json" -d "{ \"thedog\": \"enabling hardware\" }" http://10.0.0.21:25801/48

printf 'Setting up hardware'
if grep -q 'i2c-bcm2708' /etc/modules; 
then
  printf 'i2c-bcm2708 is enabled\n'
else
  printf 'Enabling i2c-bcm2708\n'
  echo 'i2c-bcm2708' | sudo tee -a /etc/modules > /dev/null
fi
if grep -q 'i2c-dev' /etc/modules; 
then
  printf 'i2c-dev is enabled\n'
else
  printf 'Enabling i2c-dev\n'
  echo 'i2c-dev' | sudo tee -a /etc/modules > /dev/null
fi
if grep -q 'dtparam=i2c1=on' /boot/config.txt; 
then
  printf 'i2c1 parameter is set\n'
else
  printf 'Setting i2c1 parameter\n'
  echo 'dtparam=i2c1=on' | sudo tee -a /boot/config.txt > /dev/null
fi
if grep -q 'dtparam=i2c_arm=on' /boot/config.txt; 
then
  printf 'i2c_arm parameter is set\n'
else
  printf 'Setting i2c_arm parameter\n'
  echo 'dtparam=i2c_arm=on' | sudo tee -a /boot/config.txt > /dev/null
fi
if [ -f /etc/modprobe.d/raspi-blacklist.conf ]; 
then
  printf 'Removing blacklist entries\n'
  sudo sed -i 's/^blacklist spi-bcm2708/#blacklist spi-bcm2708/' /etc/modprobe.d/raspi-blacklist.conf
  sudo sed -i 's/^blacklist i2c-bcm2708/#blacklist i2c-bcm2708/' /etc/modprobe.d/raspi-blacklist.conf
fi
printf '\n'

curl -s -m 2 -X POST -H "Content-Type: application/json" -d "{ \"thedog\": \"complete\" }" http://10.0.0.21:25801/48
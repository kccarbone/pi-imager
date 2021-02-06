#!/bin/bash

touch /home/pi/starting
curl -s -X POST -H "Content-Type: application/json" -d "{ \"thedog\": \"starting\" }" http://10.0.0.21:25801/48

# Update system
printf '\033[0;36mUpdating system\033[0m\n'
sudo apt update -y
sudo apt dist-upgrade -y
printf 'Update complete\n\n'

# Install Node
printf '\033[0;36mChecking Node.js\033[0m\n'
if ! type node > /dev/null 2>&1; 
then
  curl -sL https://deb.nodesource.com/setup_10.x | sudo bash -
  sudo apt install -y nodejs
fi
printf "\033[0;32mNode $(node -v)\033[0m installed\n"
printf "\033[0;32mNPM $(npm -v)\033[0m installed\n\n"

# Install Snap
printf '\033[0;36mChecking Snap\033[0m\n'
if ! type snap > /dev/null 2>&1; 
then
  sudo apt install -y snapd
  printf "Installing core...\n"
  sudo snap install core
fi
printf "Updating core...\n"
sudo snap refresh core

curl -s -X POST -H "Content-Type: application/json" -d "{ \"thedog\": \"complete\" }" http://10.0.0.21:25801/48
touch /home/pi/finished
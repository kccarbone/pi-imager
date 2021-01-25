#!/bin/bash

printf '\033[0;104m[ Creating custom pi image ]\033[0m\n\n'

# Set up wifi
printf "\033[0;33m -> Wifi SSID: \033[0m"
read -r wifiSSID
printf "\033[0;33m -> Wifi Password: \033[0m"
read -r wifiPass

# Download pi image
imageSource=https://downloads.raspberrypi.org/raspios_arm64/images/raspios_arm64-2020-08-24/2020-08-20-raspios-buster-arm64.zip

if [ ! -f raspbian.zip ];
then
  printf '\033[0;36m\nDownloading image...\033[0m\n'
  curl $imageSource -o raspbian.zip
fi

# Unzip it
if [ ! -f raspbian.img ];
then
  printf '\033[0;36m\nUnzipping image...\033[0m\n'
  unzip raspbian.zip
  for f in ./*.img; do
    mv "$f" "raspbian.img"
  done
fi

# Mount locally
loopDevice='/dev/loop4'
bootDir='/mnt/pi_boot'
rootDir='/mnt/pi_root'

sudo mkdir -p $bootDir
sudo mkdir -p $rootDir

printf '\033[0;36m\nMounting image...\033[0m\n'
sudo losetup -P "$loopDevice" raspbian.img
sudo mount "${loopDevice}p1" $bootDir
sudo mount "${loopDevice}p2" $rootDir

# Inject files
printf '\033[0;36m\nMounting image...\033[0m\n'
wifiFile="$bootDir/wpa_supplicant.conf"
sshFile="$bootDir/SSH"

# Write wifi file
sudo rm -f $wifiFile
sudo touch $wifiFile
echo 'country=US' | sudo tee -a $wifiFile > /dev/null
echo 'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev' | sudo tee -a $wifiFile > /dev/null
echo 'update_config=1' | sudo tee -a $wifiFile > /dev/null
echo '' | sudo tee -a $wifiFile > /dev/null
echo 'network={' | sudo tee -a $wifiFile > /dev/null
echo '  scan_ssid=1' | sudo tee -a $wifiFile > /dev/null  
echo "  ssid=\"$wifiSSID\"" | sudo tee -a $wifiFile > /dev/null
echo "  psk=\"$wifiPass\"" | sudo tee -a $wifiFile > /dev/null
echo '}' | sudo tee -a $wifiFile > /dev/null
printf 'Wifi enabled\n'

# Enable SSH
sudo touch $sshFile
printf 'SSH enabled\n'

# Unmount
printf '\033[0;36m\nUnmounting image...\033[0m\n'
#sudo umount $bootDir
#sudo umount $rootDir

printf '\033[0;32m\nDone!\033[0m\n'
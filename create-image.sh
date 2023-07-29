#!/bin/bash

printf '\033[0;30;104m[ Creating custom pi image ]\033[0m\n\n'

# Inputs
printf "\033[0;33m -> Default user: \033[0m"
read -r defUser
printf "\033[0;33m -> Default password: \033[0m"
read -r defPass
printf "\033[0;33m -> Wifi SSID: \033[0m"
read -r wifiSSID
printf "\033[0;33m -> Wifi password: \033[0m"
read -r wifiPass
printf "\033[0;33m -> 64-bit?: \033[0m"
read -r modernOS

# Find pi image
if [[ "$modernOS" =~ ^[yY]$|^YES$|^yes$ ]];
then
  # 64-bit image - Compatible with pi 3+ and pi zero 2+
  imageSource=https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2023-05-03/2023-05-03-raspios-bullseye-arm64-lite.img.xz
  printf "\r\033[1A\033[0K\033[0;33m -> 64-bit?:\033[0m Yes\n"
else
  # 32-bit image - Compatble with all
  imageSource=https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-09-26/2022-09-22-raspios-bullseye-armhf-lite.img.xz
  printf "\r\033[1A\033[0K\033[0;33m -> 64-bit?:\033[0m No\n"
fi

# Doanload it
if [ ! -f raspbian.img.xz ];
then
  printf '\033[0;36m\nDownloading image...\033[0m\n'
  curl $imageSource -o raspbian.img.xz
fi

# Extract it
if [ ! -f raspbian.img ];
then
  printf '\033[0;36m\nExtract image...\033[0m\n'
  unxz raspbian.img.xz
  echo 'Done!'
fi

# Mount locally
loopDevice='/dev/loop4'
bootDir='/mnt/pi_boot'
rootDir='/mnt/pi_root'

sudo mkdir -p $bootDir
sudo mkdir -p $rootDir

printf '\033[0;36m\nMounting image...\033[0m\n'
{
  sudo losetup -P "$loopDevice" raspbian.img && echo "raspbian.img mapped to $loopDevice"
  sudo mount "${loopDevice}p1" $bootDir && echo "Boot partition mapped to $bootDir"
  sudo mount "${loopDevice}p2" $rootDir && echo "Full OS partition mapped to $rootDir"
} || 
{
  printf "\033[0;91m\nFailed to access loop device.\033[0m\n"
  printf "\033[0;31;47m>> Try unmounting \033[1m$loopDevice\033[0;31;47m and run again <<\033[0m\n"
  exit 1
}

# Inject files
printf '\033[0;36m\nInjecting files...\033[0m\n'
userFile="$bootDir/userconf.txt"
wifiFile="$bootDir/wpa_supplicant.conf"
sshFile="$bootDir/SSH"

# Enable default user
encPass=$(echo "$defPass" | openssl passwd -6 -stdin)
sudo rm -f $userFile
sudo touch $userFile
echo "$defUser:$encPass" | sudo tee -a $userFile > /dev/null
printf 'Default user added\n'

# Enable WiFi
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

# Enable first-boot script
serviceName="firstboot"
serviceHome="$rootDir/etc/$serviceName"
serviceScript="$serviceHome/service.sh"
serviceFile="$rootDir/lib/systemd/system/$serviceName.service"

sudo rm -rf $serviceHome
sudo mkdir -p $serviceHome
sudo touch $serviceScript
sudo chmod +x $serviceScript
echo '#!/bin/bash' | sudo tee -a $serviceScript > /dev/null
echo 'while ! ping -n -w 1 -c 1 google.com &> /dev/null; do echo "waiting on network"; sleep 1; done' | sudo tee -a $serviceScript > /dev/null
echo 'bash <(curl -sSL http://10.0.0.50:18011/file/first-boot.sh)' | sudo tee -a $serviceScript > /dev/null
echo "sudo rm /etc/systemd/system/multi-user.target.wants/$serviceName.service" | sudo tee -a $serviceScript > /dev/null
echo 'echo "Firstboot script complete. Restarting..."' | sudo tee -a $serviceScript > /dev/null
echo 'sudo shutdown -r now' | sudo tee -a $serviceScript > /dev/null

sudo rm -f $serviceFile
sudo touch $serviceFile
echo '[Unit]' | sudo tee -a $serviceFile > /dev/null
echo 'Description=First boot setup script' | sudo tee -a $serviceFile > /dev/null
echo 'After=network-online.target' | sudo tee -a $serviceFile > /dev/null
echo '' | sudo tee -a $serviceFile > /dev/null
echo '[Service]' | sudo tee -a $serviceFile > /dev/null
echo "User=$defUser" | sudo tee -a $serviceFile > /dev/null
echo 'Type=simple' | sudo tee -a $serviceFile > /dev/null
echo "ExecStart=/etc/$serviceName/service.sh" | sudo tee -a $serviceFile > /dev/null
echo 'Restart=on-failure' | sudo tee -a $serviceFile > /dev/null
echo 'RestartSec=30' | sudo tee -a $serviceFile > /dev/null
echo 'StandardOutput=syslog' | sudo tee -a $serviceFile > /dev/null
echo 'StandardError=syslog' | sudo tee -a $serviceFile > /dev/null
echo "SyslogIdentifier=$serviceName" | sudo tee -a $serviceFile > /dev/null
echo '' | sudo tee -a $serviceFile > /dev/null
echo '[Install]' | sudo tee -a $serviceFile > /dev/null
echo 'WantedBy=multi-user.target' | sudo tee -a $serviceFile > /dev/null

sudo rm -f "$rootDir/etc/systemd/system/multi-user.target.wants/$serviceName.service"
sudo ln -s "$serviceFile" "$rootDir/etc/systemd/system/multi-user.target.wants/$serviceName.service"
printf 'First-boot service enabled\n'

# Unmount
printf '\033[0;36m\nUnmounting image...\033[0m\n'
sudo umount $bootDir && echo "Unmounted $bootDir"
sudo umount $rootDir && echo "Unmounted $bootDir"
sudo losetup -d $loopDevice && echo "raspbian.img released!"

printf '\033[0;32m\nDone!\033[0m\n'
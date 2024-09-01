#!/bin/bash

# nvme-setup.sh
# -------------------------------------------------------------
# Simple helper script to install RaspiOS on an attached NVME
# drive and copy some basic settings for a headless install.
#
# Use at your own risk!
#
# 2024 Kyle Carbone

printf '\033[0;30;107m[ Quick NVME Setup ]\033[0m\n\n'

# Look for attached device that begins with "nvme"
nvmeDev=$(sudo fdisk -l | awk -F ':' '/^Disk \/dev\/nvme/ {print $1;exit}' | cut -d ' ' -f 2)

# Fail if device not found
if [ -z "$nvmeDev" ];
then
  printf '\033[0;91mError\033[0m\n'
  printf 'NVME device not found in device tree (/dev/nvme*).\n'
  printf 'Check connections and try again.\n\n'
  exit 1
fi

# Fail if system is booting from NVME
if [ -n "$(mount | grep '/boot' | grep $nvmeDev)" ];
then
  printf '\033[0;91mError\033[0m\n'
  printf "System is currently booted from $nvmeDev.\n"
  printf 'Boot from SD card and try again.\n\n'
  exit 2
fi

# Pre-flight warning
printf '\033[0;93mWarning\033[0m\n'
printf "This will erase everything on $nvmeDev.\n"
printf 'Do you wish to continue? \033[0;90m[y/n]\033[0m '
read -r response

if [[ $response != 'y' ]];
then
  exit 3
fi

# Download pi imager
printf '\n\033[0;36m- Install dependencies...\033[0m\n'
sudo apt install rpi-imager -y

# Erase and prepare drive
printf '\n\033[0;36m- Preparing drive...\033[0m\n'
echo 'Creating new partition table...'
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' <<EOF | sudo fdisk $nvmeDev > /dev/null
  g # set file system GPT
  n # new partition
  1 # partition number 1
    # default - first sector
    # default - max size
  w # write changes!
EOF

# Download raspiOS
printf '\n\033[0;36m- Download latest RaspiOS...\033[0m\n'
rm -f raspbian.img
rm -f raspbian.img.xz
curl -L https://downloads.raspberrypi.org/raspios_lite_arm64_latest -o raspbian.img.xz
echo ""
echo "Extracting image..."
unxz raspbian.img.xz

# Install OS on drive
printf '\n\033[0;36m- Installing RaspiOS...\033[0m\n'
sudo rpi-imager --cli --enable-writing-system-drives raspbian.img $nvmeDev

# Mount new partitions
bootDir='/mnt/pi_boot'
rootDir='/mnt/pi_root'

sudo mkdir -p $bootDir
sudo mkdir -p $rootDir

printf '\n\033[0;36m- Mounting new OS...\033[0m\n'
sudo mount "${nvmeDev}p1" $bootDir && echo "Boot partition mapped to $bootDir"
sudo mount "${nvmeDev}p2" $rootDir && echo "Full OS partition mapped to $rootDir"

# Copy settings to new OS
printf '\n\033[0;36m- Setting defaults...\033[0m\n'

# Enable SSH
echo "Enabling SSH..."
sudo touch /mnt/pi_boot/SSH

# Enable default user
currentUser=$(sudo cat /etc/shadow | grep --color=never $(whoami))
userName=$(echo $currentUser | cut -d ':' -f 1)
userPass=$(echo $currentUser | cut -d ':' -f 2)

echo "Setting default user ($userName)..."
sudo rm -f /mnt/pi_boot/userconf.txt
sudo touch /mnt/pi_boot/userconf.txt
echo "$userName:$userPass" | sudo tee -a /mnt/pi_boot/userconf.txt > /dev/null

# Copy network 
echo "Copying network config..."
sudo cp -R /etc/NetworkManager/system-connections/. /mnt/pi_root/etc/NetworkManager/system-connections/

# Update boot order (B1 = SD, B2 = NVME)
printf '\n\033[0;36m- Updating boot order...\033[0m\n'
sudo raspi-config nonint do_boot_order B2

# Clean up
printf '\n\033[0;36m- Cleaning up...\033[0m\n'

echo "Unmounting drive..."
sudo umount $bootDir
sudo umount $rootDir
sudo rm -rf $bootDir
sudo rm -rf $rootDir

echo "Deleting downloads..."
rm -f raspbian.img
rm -f raspbian.img.xz

printf '\n\033[0;92mDone!\033[0m\n'
printf 'Reboot to use NVME\n\n'
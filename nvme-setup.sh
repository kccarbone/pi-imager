#!/bin/bash

# nvme-setup.sh
# -------------------------------------------------------------
# Simple helper script to install RaspiOS on an attached NVME
# drive and copy some basic settings for a headless install.
#
# Use at your own risk!
#
# 2025 Kyle Carbone

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
sudo apt install rpi-imager libopengl0 libgl1 libegl1 -y

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
if [ ! -f "raspbian.img" ]; 
then
  printf '\n\033[0;36m- Download latest RaspiOS...\033[0m\n'
  rm -f raspbian.img
  rm -f raspbian.img.xz
  curl -L https://downloads.raspberrypi.org/raspios_lite_arm64_latest -o raspbian.img.xz
  echo ""
  echo "Extracting image..."
  unxz raspbian.img.xz
  rm -f raspbian.img.xz
fi

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
printf '\n\033[0;36m- Creating setup script...\033[0m\n'

piSetup="$rootDir/etc/pisetup.sh"
sudo rm -f $piSetup
sudo touch $piSetup
printf '#!/bin/bash\n\n' | sudo tee -a $piSetup > /dev/null
printf 'printf "\\n# run at $(date)" | sudo tee -a /etc/pisetup.sh > /dev/null\n' | sudo tee -a $piSetup > /dev/null

# Set default user
currentUser=$(sudo cat /etc/shadow | grep --color=never $(whoami))
userName=$(echo $currentUser | cut -d ':' -f 1)
userPass=$(echo $currentUser | cut -d ':' -f 2)
echo "Set default user ($userName)"
printf "/usr/lib/userconf-pi/userconf '$userName' '$userPass'\n" | sudo tee -a $piSetup > /dev/null

# Set default wifi
currentWifi="/etc/NetworkManager/system-connections/preconfigured.nmconnection"
wifiSSID=$(sudo cat $currentWifi | awk -F '=' '$1 == "ssid" {print $2;exit}')
wifiPSK=$(sudo cat $currentWifi | awk -F '=' '$1 == "psk" {print $2;exit}')
echo "Set default wifi ($wifiSSID)"
printf "/usr/lib/raspberrypi-sys-mods/imager_custom set_wlan '$wifiSSID' '$wifiPSK' 'US'\n" | sudo tee -a $piSetup > /dev/null

# Enable SSH
echo "Enable SSH"
printf "/usr/lib/raspberrypi-sys-mods/imager_custom enable_ssh\n" | sudo tee -a $piSetup > /dev/null

# Finalize setup script
printf 'rm -f /etc/systemd/system/multi-user.target.wants/pisetup.service\n' | sudo tee -a $piSetup > /dev/null
printf 'printf " ## finished at $(date)" | sudo tee -a /etc/pisetup.sh > /dev/null\n' | sudo tee -a $piSetup > /dev/null
printf 'shutdown -r now\n' | sudo tee -a $piSetup > /dev/null
sudo chmod +x $piSetup

# Install service for initial setup
serviceFile="$rootDir/lib/systemd/system/pisetup.service"
serviceTarget="$rootDir/etc/systemd/system/multi-user.target.wants/pisetup.service"

sudo rm -f $serviceFile
sudo touch $serviceFile
echo '[Unit]' | sudo tee -a $serviceFile > /dev/null
echo 'Description=First boot setup script' | sudo tee -a $serviceFile > /dev/null
echo '' | sudo tee -a $serviceFile > /dev/null
echo '[Service]' | sudo tee -a $serviceFile > /dev/null
echo 'User=root' | sudo tee -a $serviceFile > /dev/null
echo 'Type=simple' | sudo tee -a $serviceFile > /dev/null
echo 'ExecStart=/etc/pisetup.sh' | sudo tee -a $serviceFile > /dev/null
echo 'StandardOutput=syslog' | sudo tee -a $serviceFile > /dev/null
echo 'StandardError=syslog' | sudo tee -a $serviceFile > /dev/null
echo 'SyslogIdentifier=pisetup' | sudo tee -a $serviceFile > /dev/null
echo '' | sudo tee -a $serviceFile > /dev/null
echo '[Install]' | sudo tee -a $serviceFile > /dev/null
echo 'WantedBy=multi-user.target' | sudo tee -a $serviceFile > /dev/null

sudo rm -f $serviceTarget
sudo ln -s $serviceFile $serviceTarget

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

printf '\n\033[0;92mDone!\033[0m\n'
printf 'Reboot to use NVME\n\n'
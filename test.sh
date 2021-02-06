#!/bin/bash


# Test
serviceScript="/home/pi/test/service.sh"
sudo mkdir -p "/home/pi/test"
sudo rm -f $serviceScript
sudo touch $serviceScript
sudo chmod +x $serviceScript
echo '#!/bin/bash' | sudo tee -a $serviceScript > /dev/null
echo 'curl -fsSL https://raw.githubusercontent.com/kccarbone/pi-imager/master/first-boot.sh | bash' | sudo tee -a $serviceScript > /dev/null
echo "rm /etc/systemd/system/multi-user.target.wants/$serviceName.service" | sudo tee -a $serviceScript > /dev/null
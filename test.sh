#!/bin/bash


# Test
serviceScript="/home/pi/test/service.sh"
sudo mkdir -p "/home/pi/test"
sudo rm -f $serviceScript
sudo touch $serviceScript
sudo chmod +x $serviceScript
echo '#!/bin/bash' | sudo tee -a $serviceScript > /dev/null
echo '' | sudo tee -a $serviceScript > /dev/null


printf '\033[0;32mTest file written!\033[0m\n'
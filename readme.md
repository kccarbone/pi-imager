## Pi Imager

Utility for burning a custom raspberry pi image with pre-configured settings

### Create Custom Image

Run this command and follow the prompts. Since the root filesystem is ext4, this works best running on a raspberry pi:
```
source <(curl -fsSL https://raw.githubusercontent.com/kccarbone/pi-imager/master/create-image.sh)
```

### Quick Setup for NVME

This command will look for an attached nvme drive, install the latest RaspiOS (lite version) on it, and update the eeprom to boot from NVME on the next reboot. 

It also applies the following tweaks so that the image can immediately be used as a headless server:

- Enable SSH
- Configure default user (by copying the logged-in user account)
- Configure network settings (by copying the existing network setup)

```
source <(curl -fsSL https://raw.githubusercontent.com/kccarbone/pi-imager/master/nvme-setup.sh)
```
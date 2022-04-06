# Raspberry Pi Cluster a.k.a Bramble

This script sets up a Raspberry Pi Cluster utilizing the [Cluster Hat](https://clusterhat.com).

https://clusterctrl.com/setup-software

## Hardware

* Raspberry Pi 3 Model B+ (or 4)
* 4 x Raspberry Pi Zero
* [Cluster HAT](https://clusterhat.com)

## Pred the SDs

Download image for the Cluster control and 4 nodes from:
https://clusterctrl.com/setup-software (or https://dist2.8086.net/clusterctrl/testing/ for new versions)

Note: These instructions assume CNAT version of the controller.

Burn to SD cards and then remount on PC/Mac and add an empty file called `ssh` to the /boot directory.

## Setup

### Controller

#### Change Password and Hostname
Fire up and log in to the cluster control Raspberry Pi with:
- Username: pi
- Password: clusterctrl

Change the password with `passwd`

Use `raspi-config` to change the hostname to `bramble` (or any other name but adjust the instructions below.)
Reboot and log back in with new password.

#### Do Updates and Base Install
```bash
sudo apt-get update && sudo apt-get -y dist-upgrade
sudo apt-get update && sudo apt-get -y upgrade

wget https://raw.githubusercontent.com/rodneyshupe/RPi_Utilities/master/setup/rpi_setup.sh
chmod +x rpi_setup.sh
sudo ./rpi_setup.sh

sudo reboot
```

### Setup Bramble
```bash
sudo true
curl https://raw.githubusercontent.com/rodneyshupe/RPi_Bramble/master/install.sh | bash
```

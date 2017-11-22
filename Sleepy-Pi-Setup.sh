#!/bin/bash

SCRIPT=$(realpath -s "$0")
SCRIPTDIR=$(dirname "$SCRIPT")

assert () {
    echo "$1"
    read -r ReadInput
    if [[ "$ReadInput" == "Y" || "$ReadInput" == "y" ]]; then
        return 1
    else
        return 0
    fi
}

echo '================================================================================ '
echo '|                                                                               |'
echo '|                   Sleepy Pi Installation Script - Jessie                      |'
echo '|                                                                               |'
echo '================================================================================ '
echo
echo "Script: $SCRIPT"
echo "Script directory: $SCRIPTDIR"
echo

# trap "set +x; sleep 5; set -x" DEBUG

# Check whether we are running sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# check if it is Jessie
osInfo=$(cat /etc/os-release)
if [[ $osInfo == *"jessie"* ]]; then
    Jessie=true
else
    echo "This script only works on Jessie at this time"
    exit 1
fi

## Detecting Pi model
RpiCPU=$(/bin/grep Revision /proc/cpuinfo | /usr/bin/cut -d ':' -f 2 | /bin/sed -e "s/ //g")
if [ "$RpiCPU" == "a02082" ]; then
    echo "RapberryPi 3 detected"
    RPi3=true
else
    # RaspberryPi 2 or 1... let's say it's 2...
    echo "RapberryPi 2 detected"
    RPi3=false
fi

assert 'Do you want to set the hostname ? (Y/n) '
if [ $? == 1 ]; then
    read -r -p 'Hostname: ' NEWHOSTNAME
    echo "Setting the hostname..."
    sed -i "s/.*/$NEWHOSTNAME/g" /etc/hostname
    sed -i "s/127.0.1.1.*/127.0.1.1\t$NEWHOSTNAME/g" /etc/hosts
else
    echo "Skipping setting the hostname..."
fi

assert 'Begin Installation ? (Y/n) '
if [ $? == 1 ]; then
    echo "Beginning installation..."
else
    echo "Aborting installation"
    exit 0
fi

set +x

## Install Arduino
echo 'Installing additional packages...'

apt-get -qq update
apt-get -qq install -y vim
apt-get -qq dist-upgrade

# ##-------------------------------------------------------------------------------------------------

# ## Install Arduino
# echo 'Installing Arduino IDE...'
# program="arduino"
# condition=$(which $program 2>/dev/null | grep -c "not found")
# if [ "$condition" -eq 0 ] ; then
#     apt-get -qq install -y arduino
# else
#     echo "Arduino IDE is already installed - skipping"
# fi

# ##-------------------------------------------------------------------------------------------------

## Enable Serial Port
# Findme look at using sed to toggle it
echo 'Enable Serial Port...'
#echo "enable_uart=1" | sudo tee -a /boot/config.txt
if grep -q 'enable_uart=1' /boot/config.txt; then
    echo 'enable_uart=1 is already set - skipping'
else
    echo 'enable_uart=1' | sudo tee -a /boot/config.txt
fi
# if [ $RPi3 = true ]; then
#     #Set Bluetooth to use the Soft UART so we can use hardware UART on /dev/ttyAMA0 for serial comms 
#     if grep -q 'pi3-miniuart-bt' /boot/config.txt; then
#         echo 'pi3-miniuart-bt is already set - skipping'
#     else
#         sed -i '/^dtoverlay=/ s/$/,pi3-miniuart-bt/' /boot/config.txt
#     fi
#     if grep -q '^core_freq=400' /boot/config.txt; then
#         echo 'The frequency of GPU processor core is set to 400MHz already - skipping'
#     else
#         echo 'Setting core_freq=400 in /boot/config.txt'
#         sed -i 's/^core_freq=.*/core_freq=400/g' /boot/config.txt
#         fi
#     else
#         if grep -q '^core_freq=250' /boot/config.txt; then
#             echo 'The frequency of GPU processor core is set to 250MHz already - skipping'
#         else
#             echo 'Setting core_freq=250 in /boot/config.txt'
#             sed -i 's/^core_freq=.*/core_freq=250/g' /boot/config.txt
#             fi
#         fi

## Disable Serial login
echo 'Disabling Serial Login...'
if [ $RPi3 != true ]; then
    # Non-RPi3
    systemctl stop serial-getty@ttyAMA0.service
    systemctl disable serial-getty@ttyAMA0.service
else
    # Rpi 3
    systemctl stop serial-getty@ttyS0.service
    systemctl disable serial-getty@ttyS0.service
fi

## Disable Boot info
echo 'Disabling Boot info...'
#sudo sed -i'bk' -e's/console=ttyAMA0,115200.//' -e's/kgdboc=tty.*00.//'  /boot/cmdline.txt
sed -i'bk' -e's/console=serial0,115200.//'  /boot/cmdline.txt

## Link the Serial Port to the Arduino IDE
echo 'Link Serial Port to Arduino IDE...'
if [ $RPi3 != true ]; then
    # Anything other than Rpi 3
    mv "$SCRIPTDIR/rpi/80-sleepypi.rules" /etc/udev/rules.d/
fi
# Note: On Rpi3 GPIO serial port defaults to ttyS0 which is what we want

##-------------------------------------------------------------------------------------------------

## Getting Sleepy Pi to shutdown the Raspberry Pi
echo 'Setting up the shutdown...'
if grep -q 'shutdowncheck.py' /etc/rc.local; then
    echo 'shutdowncheck.py is already setup - skipping...'
else
    mkdir -p /home/pi/bin/SleepyPi
    mv -f rpi/shutdowncheck.py /home/pi/bin/SleepyPi
    sed -i '/exit 0/i python /home/pi/bin/SleepyPi/shutdowncheck.py &' /etc/rc.local
    # echo "python /home/pi/bin/SleepyPi/shutdowncheck.py &" | sudo tee -a /etc/rc.local
fi

##-------------------------------------------------------------------------------------------------

# install i2c-tools
echo 'Enable I2C...'
if grep -q '#dtparam=i2c_arm=on' /boot/config.txt; then
  # uncomment
  sed -i '/dtparam=i2c_arm/s/^#//g' /boot/config.txt
else
  echo 'i2c_arm parameter already set - skipping...'
fi

echo 'Install i2c-tools...'
if hash i2cget 2>/dev/null; then
    echo 'i2c-tools are installed already - skipping...'
else
    sudo apt-get -qq install -y i2c-tools
fi

##-------------------------------------------------------------------------------------------------

## Setup RTC
echo 'Enable RTC...'
if grep -qwE "dtoverlay=|i2c-rtc,pcf8523" /boot/config.txt; then
    echo 'dtoverlay=i2c-rtc,pcf8523 is already set - skipping'
else
    sed -i '/^dtoverlay=/ s/$/,i2c-rtc,pcf8523/' /boot/config.txt
fi

sed -i '/\/run\/systemd\/system/,+2d' /lib/udev/hwclock-set
sed -i '/systz/d' /lib/udev/hwclock-set

##-------------------------------------------------------------------------------------------------

## Setup PlatformIO

echo 'Installing PlatformIO...'

sudo pip2.7 -q install -U platformio RPi.GPIO

##-------------------------------------------------------------------------------------------------
echo "Sleepy Pi setup complete!"
assert "Would you like to reboot now? y/n"
if [ $? == 1 ]; then
    echo "Now rebooting..."
    sleep 3
    reboot
fi
exit 0
##-------------------------------------------------------------------------------------------------

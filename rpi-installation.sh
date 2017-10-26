#!/bin/bash

# trap "set +x; sleep 5; set -x" DEBUG

# Check whether we are running sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

## Ensure working directory is where the script is located
cd "$(dirname "$0")" || exit 1

## Getting Sleepy Pi to shutdown the Raspberry Pi
echo 'Setting up the shutdown...'
if grep -q 'shutdowncheck.py' /etc/rc.local; then
    echo 'shutdowncheck.py is already setup - skipping...'
else
    [ ! -d /usr/local/bin/SleepyPi  ] && mkdir /usr/local/bin/SleepyPi
    cp -f rpi/shutdowncheck.py /usr/local/bin/SleepyPi
    sed -i '/exit 0/i python /usr/local/bin/SleepyPi/shutdowncheck.py &' /etc/rc.local
fi

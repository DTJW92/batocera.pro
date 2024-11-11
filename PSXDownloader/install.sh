#!/bin/bash

# Get the machine hardware name
architecture=$(uname -m)
# Check if the architecture is x86_64 (AMD/Intel)
if [ "$architecture" != "x86_64" ]; then
    echo "This script only runs on AMD or Intel (x86_64) CPUs, not on $architecture."
    exit 1
fi
# Function to display animated title
animate_title() {
    local text="BATOCERA PSX CHD INSTALLER"
    local delay=0.1
    local length=${#text}
    for (( i=0; i<length; i++ )); do
        echo -n "${text:i:1}"
        sleep $delay
    done
    echo
}
# Function to display controls
display_controls() {
    echo 
    echo "  This Will install Batocera PSX CHD Installer to Ports"
    echo    
    sleep 5  # Delay for 5 seconds
}
# Main script execution
clear
animate_title
display_controls
# Check if /userdata/system/pro does not exist and create it if necessary
if [ ! -d "/userdata/system/psxd" ]; then
    mkdir -p /userdata/system/psxd
fi
# Download pro.sh to /userdata/system/pro
curl -L https://github.com/DTJW92/batocera.pro/raw/main/PSXDownoader/psxdownloader.sh -o /userdata/system/psxd/psxdownloader.sh

# Download BatoceraPRO.sh to /userdata/roms/ports
curl -L https://github.com/DTJW92/batocera.pro/raw/main/PSXDownloader/PSXDownloader.sh -o /userdata/roms/psxd/PSXDownloader.sh

# Download BatoceraPRO.sh.keys to /userdata/roms/ports
wget  https://github.com/DTJW92/batocera.pro/raw/main/PSXDownloader/bkeys.txt -o /userdata/roms/ports/PSXDownloader.sh.keys

# Set execute permissions for the downloaded scripts
chmod +x /userdata/system/psxd/psxdownloader.sh
chmod +x /userdata/roms/ports/PSXDownloader.sh


# killall -9 emulationstation

sleep 

mv /userdata/roms/ports/bkeys.txt /userdata/roms/ports/PSXDownloader.sh.keys


echo "Finished.  You should see PSXDownloader in Ports"

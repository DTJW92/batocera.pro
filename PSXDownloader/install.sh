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
    local text="BATOCERA PSX DOWNLOADER INSTALLER"
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
    echo "  This Will install PSX Downloader to Ports"
    echo    
    sleep 5  # Delay for 5 seconds
}

# Main script execution
clear
animate_title
display_controls

# Check if /userdata/system/psxdownloader does not exist and create it if necessary
if [ ! -d "/userdata/system/psxdownloader" ]; then
    mkdir -p /userdata/system/psxdownloader
fi

# Download PSXDownloader.sh to /userdata/system/psxdownloader
curl -L https://github.com/DTJW92/batocera.pro/raw/main/PSXDownloader/PSXDownloader.sh -o /userdata/system/psxdownloader/PSXDownloader.sh

# Download PSXDownloader.sh.keys to /userdata/roms/ports
wget https://github.com/DTJW92/batocera.pro/raw/main/PSXDownloader/bkeys.txt -P /userdata/roms/ports/

# Set execute permissions for the downloaded scripts
chmod +x /userdata/system/psxdownloader/PSXDownloader.sh

killall -9 emulationstation

sleep 1

mv /userdata/roms/ports/bkeys.txt /userdata/roms/ports/PSXDownloader.sh.keys

echo "Finished. You should see PSXDownloader in Ports."

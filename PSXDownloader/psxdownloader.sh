#!/bin/bash

# Check if Zenity is installed, and install it if not
check_zenity_installed() {
    if ! command -v zenity &> /dev/null; then
        echo "Zenity not found. Installing..."
        
        # Check if the system is using apt (Debian/Ubuntu-based), yum (RHEL/CentOS-based), or pacman (Arch-based)
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y zenity
        elif command -v yum &> /dev/null; then
            sudo yum install -y zenity
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm zenity
        else
            echo "Package manager not supported. Please install Zenity manually."
            exit 1
        fi
        
        # Check if the installation was successful
        if command -v zenity &> /dev/null; then
            echo "Zenity successfully installed."
        else
            echo "Failed to install Zenity. Exiting."
            exit 1
        fi
    else
        echo "Zenity is already installed."
    fi
}

# Run the check and install Zenity if needed
check_zenity_installed

clear
zenity --info --title="Notice" --text="Note: Batocera.Pro is deprecated and going archived. Support is no longer available." --width=300
clear

# Function to display animated title with colors (No Zenity equivalent for animation, keeping this terminal-based)
animate_title() {
    local text="BATOCERA PSX DOWNLOADER"
    local delay=0.03
    local length=${#text}

    echo -ne "\e[1;36m"  # Set color to cyan
    for (( i=0; i<length; i++ )); do
        echo -n "${text:i:1}"
        sleep $delay
    done
    echo -e "\e[0m"  # Reset color
}

# Fetch list of game files from the URL and create a checklist
url="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
game_list=($(curl -s $url | grep -oP 'href="\K[^"]*' | grep -E "\.chd$"))

if [ ${#game_list[@]} -eq 0 ]; then
    zenity --error --text="No games found at $url" --width=300
    exit 1
fi

# Prepare array for dialog command, sorted by game name
declare -A games
for game in "${game_list[@]}"; do
    games["$game"]="$url$game"
done

# Prepare array for Zenity checklist
game_choices=()
for game in $(printf "%s\n" "${!games[@]}" | sort); do
    game_choices+=("$game" FALSE)
done

# Flag to track if any new file was downloaded
new_file_downloaded=false

# Main loop: Show file selection and download process
while true; do
    # Show Zenity checklist for game selection
    selected_games=$(zenity --list --checklist --title="Select PSX games to install" --column="Select" --column="Game" "${game_choices[@]}" --width=500 --height=400)

    # Check if Cancel was pressed (Zenity returns an empty string on Cancel)
    if [ -z "$selected_games" ]; then
        zenity --info --text="Installation cancelled." --width=300
        exit
    fi

    # Reset the flag for new file download
    new_file_downloaded=false

    # Install selected games
    IFS='|'  # Zenity uses | to separate selected items
    for game in $selected_games; do
        game_url="${games[$game]}"
        filename=$(basename "$game")  # Extract the file name from the URL
        destination="/userdata/roms/psx/$filename"

        echo "Attempting to download from: '$game_url'"

        # Check if the file already exists
        if [ -f "$destination" ]; then
            echo "File '$filename' already exists in /userdata/roms/psx/. Skipping download."
            continue
        fi

        rm "/tmp/$filename" 2>/dev/null
        echo "Downloading $game..."

        # Check if the URL is valid
        if [[ ! "$game_url" =~ ^https?:// ]]; then
            echo "Error: The URL for $game is not valid (Scheme missing)."
            continue
        fi

        # Create Zenity progress bar for download
        ( 
            wget --tries=10 --no-check-certificate --no-cache --no-cookies --progress=bar:force:noscroll -O "/tmp/$filename" "$game_url" 2>&1 | \
            zenity --progress --title="Downloading $game" --text="Downloading..." --percentage=0 --auto-close --width=500 --height=100
        )
        wget_exit_code=$?

        if [[ $wget_exit_code -eq 0 && -s "/tmp/$filename" ]]; then
            chmod 777 "/tmp/$filename" 2>/dev/null
            mv "/tmp/$filename" "$destination"
            clear
            echo -e "\n\n$game installation complete.\n\n"

            # Set the flag to true if a file was downloaded
            new_file_downloaded=true
        else
            zenity --error --text="Error: couldn't download game $game" --width=300
            cat /tmp/.download_log  # Show wget logs in the terminal
        fi
    done

    # Reload ES after installations
    curl http://127.0.0.1:1234/reloadgames

    # Exit the loop only if a new file was downloaded
    if $new_file_downloaded; then
        zenity --info --text="Exiting after successful download." --width=300
        exit
    else
        # Add a 3-second delay before returning to file selection
        zenity --info --text="No new files were downloaded. Returning to file selection in 3 seconds..." --width=300
        sleep 3
    fi
done

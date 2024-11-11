#!/bin/bash

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

# Prepare array for checklist
declare -A games
for game in "${game_list[@]}"; do
    games["$game"]="$url$game"
done

# Prepare array for checklist
game_choices=()
for game in $(printf "%s\n" "${!games[@]}" | sort); do
    game_choices+=("$game" "" OFF)
done

# Flag to track if any new file was downloaded
new_file_downloaded=false

# Main loop: Show file selection and download process
while true; do
    # Show Zenity checklist for game selection
    selected_games=$(zenity --list --checklist --title="Select PSX games to install" --column="Select" --column="Game" "${game_choices[@]}" --width=500 --height=400 --multiple)

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

        # Start Zenity progress bar with initial text (without progress value yet)
        progress_pid=$(zenity --progress --title="Downloading $game" --text="Attempting to download from: $game_url" --percentage=0 --auto-close --width=300 --height=100 &)

        # Check if the file already exists
        if [ -f "$destination" ]; then
            zenity --info --text="File '$filename' already exists. Skipping download." --width=300
            continue
        fi

        # Remove any previous temporary files
        rm "/tmp/$filename" 2>/dev/null

        # Update Zenity progress with the "Downloading" message
        zenity --progress --title="Downloading $game" --text="Downloading $game..." --percentage=0 --width=300 --height=100 &

        # Check if the URL is valid
        if [[ ! "$game_url" =~ ^https?:// ]]; then
            zenity --error --text="Error: The URL for $game is not valid (Scheme missing)." --width=300
            continue
        fi

        # Run wget and capture output, update progress in Zenity dialog
        download_output=$(wget --tries=10 --no-check-certificate --no-cache --no-cookies --progress=dot:mega -O "/tmp/$filename" "$game_url" 2>&1)
        wget_exit_code=$?

        # If wget works and the file was downloaded, move it
        if [[ $wget_exit_code -eq 0 && -s "/tmp/$filename" ]]; then
            chmod 777 "/tmp/$filename" 2>/dev/null
            mv "/tmp/$filename" "$destination"
            clear
            zenity --info --text="$game installation complete." --width=300

            # Set the flag to true if a file was downloaded
            new_file_downloaded=true
        else
            # Print the wget error message
            zenity --error --text="Error: couldn't download game $game. \n\nError Message:\n$download_output" --width=300
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
        zenity --info --text="No new files were downloaded. Press OK to return to selection." --width=300
        sleep 3
    fi
done

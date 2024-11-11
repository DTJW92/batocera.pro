#!/bin/bash

# Function to fetch .chd file list from the given URL
fetch_chd_list() {
    curl -s "https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/" | \
        grep -oP 'href="\K[^"]*' | \
        grep -E "\.chd$"
}

# Function to extract clean, decoded game titles from file names
extract_game_titles() {
    local files=("$@")
    declare -A title_to_file_map=()
    for file in "${files[@]}"; do
        # Strip the .chd extension, decode HTML entities, clean up, and remove content within parentheses
        title=$(basename "$file" .chd | \
            sed 's/%20/ /g; s/%28/(/g; s/%29/)/g' | \
            sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'\''/g; s/&apos;/'\''/g' | \
            sed 's/([^)]*)//g' | \
            tr -s ' ')  # This will replace multiple spaces with a single space and remove leading/trailing spaces
        
        title_to_file_map["$title"]="$file"
    done
    # Sort titles alphabetically
    for title in $(echo "${!title_to_file_map[@]}" | tr ' ' '\n' | sort); do
        echo "${title_to_file_map[$title]} - $title"
    done
}

# Function to download files, skipping existing ones
download_files() {
    local files=("$@")
    for file in "${files[@]}"; do
        game_title=$(basename "$file" .chd)
        game_title=$(echo "$game_title" | sed 's/%20/ /g; s/%28/(/g; s/%29/)/g' | \
            sed 's/&amp;/\&/g; s/&lt;/</g; s/&gt;/>/g; s/&quot;/"/g; s/&#39;/'\''/g; s/&apos;/'\''/g' | \
            sed 's/([^)]*)//g' | tr -s ' ')

        # Check if the file already exists
        if [ -e "/userdata/roms/psx/$game_title.chd" ]; then
            echo "$game_title already exists, skipping download."
        else
            # Show progress with dialog
            dialog --title "Downloading $game_title" --gauge "Downloading $game_title..." 10 70 0
            curl -s -O "https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/$file"  # Download file
            mv "$file" "/userdata/roms/psx/$game_title.chd"  # Move to correct folder
            dialog --title "Download Complete" --msgbox "$game_title has been downloaded!" 5 30
        fi
    done
}

# Main function
main() {
    while true; do
        # Fetch the list of .chd files
        files=$(fetch_chd_list)
        if [ -z "$files" ]; then
            dialog --msgbox "No CHD files found." 10 50
            return
        fi

        # Extract the game titles from the file names
        game_titles=$(extract_game_titles $files)

        # Let the user select games
        selected_titles=$(dialog --title "Select Games" --checklist \
            "Select the games to download:" 15 60 8 \
            $(for title in $game_titles; do
                game_file=$(echo $title | awk '{print $1}')
                game_name=$(echo $title | cut -d ' ' -f 2-)
                echo "$game_name" "$game_name" off
            done) 2>&1 >/dev/tty)

        # Check if user canceled
        if [ $? -eq 1 ]; then
            break
        fi

        # Download the selected files
        download_files $selected_titles

        # Ask if the user wants to refresh the game list or exit
        response=$(dialog --title "Update Game List" --yesno "Do you want to refresh the game list?" 7 60)
        if [ $? -eq 0 ]; then
            curl http://127.0.0.1:1234/reloadgames  # Refresh game list in Batocera
        fi

        # Exit the loop
        break
    done
}

# Run the main function
main

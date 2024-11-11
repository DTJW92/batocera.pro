#!/bin/bash

# URL of the directory containing the .chd files
BASE_URL="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
DEST_DIR="/userdata/roms/psx"

# Create the destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Function to fetch and filter .chd file list using improved grep pattern
fetch_chd_list() {
    curl -s "$BASE_URL" | grep -oP 'href="\K[^"]*' | grep -E "\.chd$" | sort
}

# Function to download files with a progress bar displayed using dialog
download_with_progress() {
    local files=("$@")
    local total_files=${#files[@]}
    local current_file=1
    local tempfile=$(mktemp)

    for file in "${files[@]}"; do
        local filename=$(basename "$file")
        local dest_file="$DEST_DIR/$filename"
        
        # Check if the file already exists and skip if so
        if [[ -f "$dest_file" ]]; then
            echo "File '$filename' already exists, skipping..." >> "$tempfile"
            dialog --title "Skipping $filename" --infobox "File already exists, skipping: $filename" 7 50
            sleep 1  # Short pause for the message to be visible
            continue
        fi

        # Display the progress bar with filename
        dialog --title "Downloading $filename" --gauge "Downloading file $current_file of $total_files:\n$filename" 10 70 0

        # Download file and update progress in real time
        curl -L "$BASE_URL$file" -o "$dest_file" --progress-bar | while read -r line; do
            if [[ "$line" =~ ([0-9]+)% ]]; then
                percent=${BASH_REMATCH[1]}
                echo "$percent" | dialog --title "Downloading $filename" --gauge "Downloading file $current_file of $total_files:\n$filename" 10 70
            fi
        done

        current_file=$((current_file + 1))
    done

    rm -f "$tempfile"
}

# Function to refresh the game list with cancellation option
refresh_game_list() {
    dialog --title "Refresh Game List" --yesno "Would you like to refresh the game list?" 7 50
    if [ $? -eq 0 ]; then
        dialog --msgbox "Refreshing game list..." 6 40
        curl http://127.0.0.1:1234/reloadgames  # Reload the games list in Batocera
        dialog --msgbox "Game list refreshed successfully!" 6 40
    else
        dialog --msgbox "Game list refresh cancelled." 6 40
    fi
}

# Main function to display the dialog interface
main() {
    while true; do
        # Fetch the list of .chd files
        files=$(fetch_chd_list)

        # Prepare array for dialog command, sorted alphabetically
        dialog_items=()
        for file in $files; do
            dialog_items+=("$file" "" OFF)  # Default to unselected
        done

        # Show dialog checklist to select files
        cmd=(dialog --separate-output --checklist "Select games to download" 22 76 16)
        selections=$("${cmd[@]}" "${dialog_items[@]}" 2>&1 >/dev/tty)

        # Check if Cancel was pressed
        if [ $? -eq 1 ]; then
            dialog --msgbox "Download cancelled." 6 30
            refresh_game_list  # Refresh game list before exiting
            exit
        fi

        # If no files are selected, show a message and return to the menu
        if [ -z "$selections" ]; then
            dialog --msgbox "No files selected. Returning to the file list." 6 30
            continue
        fi

        # Download and move selected files
        download_with_progress $selections

        # Display download results
        dialog --msgbox "Download completed." 10 50

        # Ask if user wants to select more files
        dialog --yesno "Would you like to select more files?" 7 50
        if [ $? -ne 0 ]; then
            dialog --msgbox "Exiting." 6 30
            refresh_game_list  # Refresh game list before exiting
            break
        fi
    done
}

# Run the main function
main

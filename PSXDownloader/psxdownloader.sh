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

# Function to handle the download process with a progress bar
download_with_progress() {
    local file
    local skipped=0
    local downloaded=0
    local total_files=0

    # Count the total number of files to download
    total_files=$(echo "$@" | wc -w)

    # Set up a temporary file to hold the progress info
    tempfile=$(mktemp)

    # Start the progress bar in dialog
    dialog --title "Downloading Files" --gauge "Downloading .chd files..." 10 70 0 < "$tempfile" &

    # Download and move files one by one
    for i in $@; do
        local filename=$(basename "$i")
        local dest_file="$DEST_DIR/$filename"
        
        # Skip if the file already exists
        if [[ -f "$dest_file" ]]; then
            skipped=$((skipped + 1))
            continue
        fi

        # Download the file using curl with a progress bar
        {
            echo "XXX" # First line to initialize the progress bar
            curl -L "$BASE_URL$i" -o "$filename" --progress-bar | while IFS= read -r line; do
                # Update the progress bar every time progress is shown
                echo $line
            done
        } > "$tempfile" &

        # Wait for download to complete
        wait $!

        # If the file is a valid .chd file, move it to the destination directory
        if [[ -f "$filename" && "${filename: -4}" == ".chd" ]]; then
            mv "$filename" "$DEST_DIR"
            downloaded=$((downloaded + 1))
        else
            dialog --msgbox "Error downloading file: $i or file is not a .chd" 6 40
            rm -f "$filename"  # Remove the incorrectly downloaded file
        fi

        # Update progress in the dialog gauge
        current_progress=$((downloaded * 100 / total_files))
        echo $current_progress
    done

    # Return the status of download vs skip
    echo "$downloaded,$skipped"
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
        result=$(download_with_progress $selections)
        IFS=',' read -r downloaded skipped <<< "$result"

        # If all files were skipped (already downloaded), return to file selection
        if [ "$downloaded" -eq 0 ] && [ "$skipped" -gt 0 ]; then
            dialog --msgbox "All selected files are already downloaded. Returning to the file list." 6 30
            continue
        fi

        # Display download results
        dialog --msgbox "Downloaded: $downloaded\nSkipped: $skipped" 10 50

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

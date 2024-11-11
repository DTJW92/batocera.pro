#!/bin/bash

# URL of the directory containing the .chd files
BASE_URL="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
DEST_DIR="/userdata/roms/psx"

# Create the destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Function to fetch and filter .chd file list
fetch_chd_list() {
    curl -s "$BASE_URL" | grep -oP 'href="([^"]+\.chd)"' | sed 's/href="\([^"]\+\)"/\1/' | sort
}

# Function to handle the download and move process
download_and_move() {
    local file
    local skipped=0
    local downloaded=0

    for file in "$@"; do
        local filename=$(basename "$file")
        local dest_file="$DEST_DIR/$filename"
        
        # Skip if the file already exists
        if [[ -f "$dest_file" ]]; then
            echo "$filename already exists. Skipping..."
            skipped=$((skipped + 1))
            continue
        fi

        # Download and move the file
        echo "Downloading $filename..."
        curl -O "$BASE_URL$file"
        
        # Check if the file was successfully downloaded
        if [[ -f "$filename" ]]; then
            mv "$filename" "$DEST_DIR"
            echo "$filename moved to $DEST_DIR"
            downloaded=$((downloaded + 1))
        else
            echo "Failed to download $filename"
        fi
    done

    # Return the status of download vs skip
    echo "Downloaded: $downloaded, Skipped: $skipped"
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
            echo "Download cancelled."
            exit
        fi

        # If no files are selected, show a message and return to the menu
        if [ -z "$selections" ]; then
            echo "No files selected. Returning to the file list."
            continue
        fi

        # Download and move selected files
        download_and_move $selections

        # Ask if user wants to select more files
        echo "Would you like to select more files? (y/n)"
        read -r response
        if [[ "$response" != "y" && "$response" != "Y" ]]; then
            echo "Exiting."
            break
        fi
    done
}

# Run the main function
main

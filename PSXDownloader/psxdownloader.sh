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
    for file in "$@"; do
        local filename=$(basename "$file")
        local dest_file="$DEST_DIR/$filename"
        
        # Skip if the file already exists
        if [[ -f "$dest_file" ]]; then
            echo "$filename already exists. Skipping..."
            continue
        fi

        # Download and move the file
        echo "Downloading $filename..."
        curl -O "$BASE_URL$file"
        
        # Check if the file was successfully downloaded
        if [[ -f "$filename" ]]; then
            mv "$filename" "$DEST_DIR"
            echo "$filename moved to $DEST_DIR"
        else
            echo "Failed to download $filename"
        fi
    done
}

# Main function to display the dialog interface
main() {
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

    # Download and move selected files
    for selection in $selections; do
        download_and_move "$selection"
    done

    echo "All selected files have been downloaded and moved."
}

# Run the main function
main

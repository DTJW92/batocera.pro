#!/bin/bash

# Open xterm and run the script inside it
xterm -hold -e '
# URL of the directory containing the .chd files
BASE_URL="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
DEST_DIR="/userdata/roms/psx"

# Create the destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Function to fetch and filter .chd file list
fetch_chd_list() {
    curl -s "$BASE_URL" | grep -oP "href=\"([^\"]+\.chd)\"" | sed "s/href=\"\([^\"]\+\)\"/\1/" | sort
}

# Display the file list with an option to filter by starting letter
filter_files() {
    local filter="$1"
    fetch_chd_list | grep -i "^$filter"
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

# Main function to allow user interaction
main() {
    echo "Select the starting letter to filter files or press Enter to show all:"
    read -r filter

    # Show the filtered file list
    files=$(filter_files "$filter")

    # Display the files
    echo "Available games:"
    echo "$files"

    if [[ -z "$files" ]]; then
        echo "No games found matching the filter."
        exit 1
    fi

    # Ask for selection
    echo "Enter the game numbers you want to download (separate with spaces):"
    select_option=$(echo "$files" | nl)

    echo "$select_option"
    
    # Prompt user to select the files by number
    echo "Enter numbers of games to download, separated by spaces:"
    read -r selected_numbers

    # Create an array from selected numbers and map to the corresponding files
    selected_files=()
    for number in $selected_numbers; do
        selected_files+=($(echo "$files" | sed -n "${number}p"))
    done

    # Download and move selected files
    download_and_move "${selected_files[@]}"
}

# Run the script
main
'

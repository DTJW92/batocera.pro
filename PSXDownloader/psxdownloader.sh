#!/bin/bash

# URL of the directory containing the .chd files
BASE_URL="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
DEST_DIR="/userdata/roms/psx"

# Create the destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Function to fetch and filter .chd file list
fetch_chd_list() {
    curl -s "$BASE_URL" | grep -oP 'href="\K[^"]*' | grep -E "\.chd$" | sort  # Ensure it's sorted alphabetically
}

# Function to decode percent-encoded characters
decode_url() {
    # Use sed to decode any URL-encoded characters (e.g., %20, %21, etc.)
    echo "$1" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g' | xargs -0 printf "%b"
}

# Function to extract clean, decoded game titles from file names
extract_game_titles() {
    local files=("$@")
    declare -A title_to_file_map=()
    for file in "${files[@]}"; do
        # Strip the .chd extension
        title=$(basename "$file" .chd)
        
        # Decode any URL-encoded characters
        title=$(decode_url "$title")
        
        # Remove any content inside parentheses, including the parentheses
        title=$(echo "$title" | sed 's/([^)]*)//g')
        
        # Map the cleaned title to the file
        title_to_file_map["$title"]="$file"
    done
    declare -p title_to_file_map
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
        # Fetch the list of .chd files and sort them
        files=($(fetch_chd_list))
        
        # Extract game titles and map them to files
        eval "$(extract_game_titles "${files[@]}")"  # Evaluate to access title_to_file_map as an array

        # Prepare array for dialog command, using game titles for display
        dialog_items=()
        for title in "${!title_to_file_map[@]}"; do
            dialog_items+=("$title" "" OFF)  # Use game title only, hide file name
        done

        # Sort the dialog items alphabetically
        dialog_items_sorted=($(for item in "${dialog_items[@]}"; do echo "$item"; done | sort))

        # Show dialog menu for selecting game categories
        menu_options=(
            "All Games" "All Games",
            "A" "A",
            "B" "B",
            "C" "C",
            "D" "D",
            "E" "E",
            "F" "F",
            "G" "G",
            "H" "H",
            "I" "I",
            "J" "J",
            "K" "K",
            "L" "L",
            "M" "M",
            "N" "N",
            "O" "O",
            "P" "P",
            "Q" "Q",
            "R" "R",
            "S" "S",
            "T" "T",
            "U" "U",
            "V" "V",
            "W" "W",
            "X" "X",
            "Y" "Y",
            "Z" "Z",
            "#" "#"
        )

        cmd=(dialog --separate-output --menu "Select a category" 22 76 16)
        selections=$("${cmd[@]}" "${menu_options[@]}" 2>&1 >/dev/tty)

        # If Cancel is pressed, exit the script
        if [ $? -eq 1 ]; then
            dialog --msgbox "Download cancelled." 6 30
            refresh_game_list  # Refresh game list before exiting
            exit
        fi

        # Process the selection
        case "$selections" in
            "All Games")
                selected_files=("${files[@]}")  # Select all files
                ;;
            "#")
                selected_files=($(echo "${files[@]}" | grep -E '^[0-9]'))  # Select files that start with a number
                ;;
            *)
                selected_files=($(echo "${files[@]}" | grep -i "^$selections"))  # Select files that start with the selected letter
                ;;
        esac

        # If no files are selected, exit immediately
        if [ -z "$selected_files" ]; then
            dialog --msgbox "No files selected. Exiting." 6 30
            exit
        fi

        # Extract game titles and map them to files again
        eval "$(extract_game_titles "${selected_files[@]}")"
        
        # Prepare array for dialog checklist
        dialog_items=()
        for title in "${!title_to_file_map[@]}"; do
            dialog_items+=("$title" "" OFF)
        done
        
        # Sort the items alphabetically before displaying them
        dialog_items_sorted=($(for item in "${dialog_items[@]}"; do echo "$item"; done | sort))

        # Show checklist for file selection
        cmd=(dialog --separate-output --checklist "Select games to download" 22 76 16)
        selections=$("${cmd[@]}" "${dialog_items_sorted[@]}" 2>&1 >/dev/tty)

        # If Cancel is pressed, exit the script
        if [ $? -eq 1 ]; then
            dialog --msgbox "Exiting." 6 30
            refresh_game_list  # Refresh game list before exiting
            exit
        fi

        # If no files are selected, exit immediately
        if [ -z "$selections" ]; then
            dialog --msgbox "No files selected. Exiting." 6 30
            exit
        fi

        # Convert selected game titles back to filenames using the map
        selected_files=()
        for title in $selections; do
            selected_files+=("${title_to_file_map[$title]}")
        done

        # Download and move selected files
        download_with_progress "${selected_files[@]}"

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

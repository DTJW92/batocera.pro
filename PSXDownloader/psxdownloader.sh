# Function to fetch and filter .chd file list
fetch_chd_list() {
    curl -s "$BASE_URL" | grep -oP 'href="\K[^"]*' | grep -E "\.chd$" | sort  # Ensure it's sorted alphabetically
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

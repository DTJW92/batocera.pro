#!/bin/bash

# URL decode function to replace '%20' with spaces
url_decode() {
    echo -e "$(echo "$1" | sed 's/%20/ /g')"
}

# Function to fetch and display the list of files from the website
fetch_files() {
    # Fetch the HTML content of the website
    files=$(curl -s "https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/")
    
    # Extract file links (files with the .chd extension) and sort them
    file_list=($(echo "$files" | grep -oP 'href="\K([^"]+\.chd)' | sort))

    # Declare an associative array to group files by their first letter
    declare -A file_groups

    # Loop through each file in the list
    for file in "${file_list[@]}"; do
        # Decode the filename from URL encoding
        decoded_name=$(url_decode "$file")
        
        # Get the first letter of the decoded filename and convert to uppercase
        first_letter=$(echo "$decoded_name" | cut -c1 | tr 'a-z' 'A-Z')
        
        # Add the decoded file name to the appropriate letter group
        file_groups[$first_letter]+="$decoded_name"$'\n'
    done
    
    # Allow the user to browse files by letter
    while true; do
        # Display the alphabetic groups (A-Z)
        echo "Please choose a letter (A-Z) to browse files or type 'exit' to quit:"
        for letter in {A..Z}; do
            # Display the group for the current letter
            echo "[$letter]"
            if [[ -n "${file_groups[$letter]}" ]]; then
                echo -e "${file_groups[$letter]}"
            else
                echo "No files."
            fi
        done

        # Prompt the user for a letter or 'exit'
        read -p "Enter letter to browse or 'exit' to quit: " user_input

        # Exit the loop if the user types 'exit'
        if [[ "$user_input" == "exit" ]]; then
            echo "Exiting the browser."
            break
        fi

        # Validate if the input is a single letter A-Z
        if [[ "$user_input" =~ ^[A-Za-z]$ ]]; then
            letter=$(echo "$user_input" | tr 'a-z' 'A-Z')  # Convert to uppercase if needed
            echo "Files starting with $letter:"
            # Display the files for the chosen letter
            if [[ -n "${file_groups[$letter]}" ]]; then
                echo -e "${file_groups[$letter]}"
            else
                echo "No files found for $letter."
            fi
        else
            echo "Invalid input. Please enter a letter from A-Z or 'exit' to quit."
        fi
    done
}

# Main program to fetch and display files
fetch_files

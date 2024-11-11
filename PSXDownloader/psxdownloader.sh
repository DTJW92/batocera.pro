#!/bin/bash

set -x  # Enable debugging to print each command

# URL of the directory containing the .chd files
BASE_URL="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
DEST_DIR="/userdata/roms/psx"

# Create the destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Function to fetch and filter .chd file list
fetch_chd_list() {
    curl -s "$BASE_URL" | grep -oP 'href="\K[^"]*' | grep -E "\.chd$" | sort
}

# Function to decode percent-encoded characters
decode_url() {
    echo "$1" | sed 's/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g' | xargs -0 printf "%b"
}

# Function to extract clean, decoded game titles from file names
extract_game_titles() {
    local files=("$@")
    declare -A title_to_file_map=()
    for file in "${files[@]}"; do
        title=$(basename "$file" .chd)
        title=$(decode_url "$title")
        title=$(echo "$title" | sed 's/([^)]*)//g')
        title_to_file_map["$title"]="$file"
    done

    sorted_titles=$(for title in "${!title_to_file_map[@]}"; do echo "$title"; done | sort)
    echo "$sorted_titles"
}

# Function to filter titles by the first letter or number
filter_by_letter_or_number() {
    local titles=("$@")
    letter_or_number=$(dialog --title "Filter Games by Letter or Number" --menu "Select a letter or number to filter by:" 15 50 28 \
        A "A" \
        B "B" \
        C "C" \
        D "D" \
        E "E" \
        F "F" \
        G "G" \
        H "H" \
        I "I" \
        J "J" \
        K "K" \
        L "L" \
        M "M" \
        N "N" \
        O "O" \
        P "P" \
        Q "Q" \
        R "R" \
        S "S" \
        T "T" \
        U "U" \
        V "V" \
        W "W" \
        X "X" \
        Y "Y" \
        Z "Z" \
        "#" "Numbers" 2>&1 >/dev/tty)

    filtered_titles=()
    if [[ "$letter_or_number" == "#" ]]; then
        for title in "${titles[@]}"; do
            if [[ "${title:0:1}" =~ [0-9] ]]; then
                filtered_titles+=("$title")
            fi
        done
    else
        for title in "${titles[@]}"; do
            if [[ "${title,,}" =~ ^$letter_or_number ]]; then
                filtered_titles+=("$title")
            fi
        done
    fi

    echo "${filtered_titles[@]}"
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
        
        if [[ -f "$dest_file" ]]; then
            echo "File '$filename' already exists, skipping..." >> "$tempfile"
            dialog --title "Skipping $filename" --infobox "File already exists, skipping: $filename" 7 50
            sleep 1
            continue
        fi

        dialog --title "Downloading $filename" --gauge "Downloading file $current_file of $total_files:\n$filename" 10 70 0

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
        curl http://127.0.0.1:1234/reloadgames
        dialog --msgbox "Game list refreshed successfully!" 6 40
    else
        dialog --msgbox "Game list refresh cancelled." 6 40
    fi
}

# Main function to display the dialog interface
main() {
    while true; do
        files=($(fetch_chd_list))
        sorted_titles=($(extract_game_titles "${files[@]}"))

        sorted_titles=($(filter_by_letter_or_number "${sorted_titles[@]}"))

        dialog_items=()
        for title in "${sorted_titles[@]}"; do
            dialog_items+=("$title" "" OFF)
        done

        cmd=(dialog --separate-output --checklist "Select games to download" 22 76 16)
        selections=$("${cmd[@]}" "${dialog_items[@]}" 2>&1 >/dev/tty)

        if [ $? -eq 1 ]; then
            dialog --msgbox "Download cancelled." 6 30
            refresh_game_list
            exit
        fi

        if [ -z "$selections" ]; then
            dialog --msgbox "No files selected. Returning to the file list." 6 30
            continue
        fi

        selected_files=()
        for title in $selections; do
            selected_files+=("${title_to_file_map[$title]}")
        done

        download_with_progress "${selected_files[@]}"

        dialog --msgbox "Download completed." 10 50

        dialog --yesno "Would you like to select more files?" 7 50
        if [ $? -ne 0 ]; then
            dialog --msgbox "Exiting." 6 30
            refresh_game_list
            break
        fi
    done
}

main

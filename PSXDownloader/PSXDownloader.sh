#!/bin/bash

# Define variables
SOURCE_URL="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
DESTINATION_FOLDER="/userdata/roms/psx"  # Set destination to the PSX ROM folder
TOTAL_SIZE=0  # Initialize total download size

# Create destination folder if it doesn't exist
mkdir -p "$DESTINATION_FOLDER"

# Step 1: Fetch list of downloadable links
echo "Fetching download links from $SOURCE_URL..."
FILE_URLS=$(curl -s "$SOURCE_URL" | grep -oP '(?<=href=")[^"]*' | grep '\.chd$')

# Step 2: Prepare file list for dialog selection
file_list=()
for file in $FILE_URLS; do
    file_list+=("$file" "" OFF)
done

# Step 3: Display selection menu
cmd=(dialog --separate-output --checklist "Select files to download:" 22 76 16)
selected_files=$("${cmd[@]}" "${file_list[@]}" 2>&1 >/dev/tty)

# Check if user canceled
if [ $? -ne 0 ]; then
    echo "Download canceled."
    exit
fi

# Step 4: Calculate total download size and set up progress tracking
echo "Calculating download size..."
for FILE_URL in $selected_files; do
    FULL_URL="$SOURCE_URL$FILE_URL"
    FILE_SIZE=$(curl -sI "$FULL_URL" | grep -i Content-Length | awk '{print $2}' | tr -d '\r')
    TOTAL_SIZE=$((TOTAL_SIZE + FILE_SIZE))
done

# Initialize progress tracking variables
downloaded_size=0
progress=0

# Step 5: Download files with progress bar
(
for FILE_URL in $selected_files; do
    FULL_URL="$SOURCE_URL$FILE_URL"
    FILE_NAME=$(basename "$FULL_URL")

    # Download file and track progress
    curl -s "$FULL_URL" -o "$DESTINATION_FOLDER/$FILE_NAME" --progress-bar | \
    while IFS= read -r -n 100 line; do
        # Calculate downloaded file size
        current_size=$(stat -c%s "$DESTINATION_FOLDER/$FILE_NAME" 2>/dev/null)
        downloaded_size=$((downloaded_size + current_size))
        progress=$((100 * downloaded_size / TOTAL_SIZE))
        echo $progress
    done
done
) | dialog --gauge "Downloading selected files..." 10 70 0

# Completion message
dialog --msgbox "All selected files downloaded to $DESTINATION_FOLDER." 10 70
clear
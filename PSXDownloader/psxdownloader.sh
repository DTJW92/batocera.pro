#!/bin/bash
clear
dialog --msgbox "Note: Batocera.Pro is deprecated and going archived. Support is no longer available." 20 70
clear

# Function to display animated title with colors
animate_title() {
    local text="BATOCERA PSX DOWNLOADER"
    local delay=0.03
    local length=${#text}
    echo -ne "\e[1;36m"  # Set color to cyan
    for (( i=0; i<length; i++ )); do
        echo -n "${text:i:1}"
        sleep $delay
    done
    echo -e "\e[0m"  # Reset color
}

# Function to display animated border
animate_border() {
    local char="#"
    local width=50
    for (( i=0; i<width; i++ )); do
        echo -n "$char"
        sleep 0.02
    done
    echo
}

# Function to display controls
display_controls() {
    echo -e "\e[1;32m"  # Set color to green
    echo "Controls:"
    echo "  Navigate with up-down-left-right"
    echo "  Select game with A/B/SPACE and execute with Start/X/Y/ENTER"
    echo -e "\e[0m"  # Reset color
    sleep 4
}

# Function to display loading animation
loading_animation() {
    local delay=0.1
    local spinstr='|/-\'
    echo -n "Loading "
    while :; do
        for (( i=0; i<${#spinstr}; i++ )); do
            echo -ne "${spinstr:i:1}"
            echo -ne "\010"
            sleep $delay
        done
    done &
    spinner_pid=$!
    sleep 3
    kill $spinner_pid
    echo "Done!"
}

url_decode() {
    echo -e "$(echo "$1" | sed 's/%20/ /g')"
}

# Fetch list of game files from the URL and create a checklist
url="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
game_list=($(curl -s $url | grep -oP 'href="\K[^"]*' | grep -E "\.chd$"))

if [ ${#game_list[@]} -eq 0 ]; then
    echo "No games found at $url"
    exit 1
fi

# Prepare array for dialog command, sorted by game name
declare -A games
for game in "${game_list[@]}"; do
    game_url=$(url_decode "$url$game")
    games["$game"]="$game_url"
done

# Prepare array for dialog checklist
game_choices=()
for game in $(printf "%s\n" "${!games[@]}" | sort); do
    game_choices+=("$game" "" OFF)
done

# Show dialog checklist for game selection
cmd=(dialog --separate-output --checklist "Select PSX games to install:" 22 76 16)
selected_games=$("${cmd[@]}" "${game_choices[@]}" 2>&1 >/dev/tty)

# Check if Cancel was pressed
if [ $? -eq 1 ]; then
    echo "Installation cancelled."
    exit
fi

# Function to handle download with progress
download_progress() {
    local game_url=$1
    local filename=$2
    local total_size
    local current_size
    local speed
    local progress

    # Start curl in silent mode to capture the total size
    total_size=$(curl -sI "$game_url" | grep -i "Content-Length" | awk '{print $2}' | tr -d '\r')

    if [ -z "$total_size" ]; then
        echo "Error: Couldn't fetch file size for $filename."
        return 1
    fi

    # Download the file with progress bar
    curl -L --silent --show-error --progress-bar -o "/tmp/$filename" "$game_url" | while IFS= read -r line; do
        if [[ "$line" =~ (\d+)% ]]; then
            current_size=${BASH_REMATCH[1]}
            progress=$((current_size * 100 / total_size))
            # Get download speed
            speed=$(echo "$line" | grep -oP "\d+\.?\d* [KMGT]B/s" || echo "Calculating speed...")
            echo -ne "\rDownloading $filename... [$progress%] $current_size/$total_size bytes, $speed"
        fi
    done

    echo -ne "\n"  # Move to the next line after download completion
}

# Install selected games
for game in $selected_games; do
    game_url="${games[$game]}"
    filename=$(basename "$game")  # Extract the file name from the URL

    # Log the full URL for debugging purposes
    echo "Attempting to download from: $game_url"

    rm "/tmp/$filename" 2>/dev/null
    echo "Downloading $game..."

    # Check if the URL is valid
    if [[ ! "$game_url" =~ ^https?:// ]]; then
        echo "Error: The URL for $game is not valid (Scheme missing)."
        echo "URL attempted: '$game_url'"
        continue
    fi

    # Retry logic for failed downloads
    attempt=0
    max_attempts=3
    while [ $attempt -lt $max_attempts ]; do
        download_progress "$game_url" "$filename"
        if [ -s "/tmp/$filename" ]; then
            chmod 777 "/tmp/$filename" 2>/dev/null
            mv "/tmp/$filename" "/userdata/roms/psx/"
            clear
            loading_animation
            echo -e "\n\n$game installation complete.\n\n"
            break
        else
            attempt=$((attempt + 1))
            echo "Attempt $attempt of $max_attempts failed. Retrying..."
            sleep 2
        fi
    done

    # If download failed after all attempts
    if [ ! -s "/tmp/$filename" ]; then
        echo "Error: Couldn't download $game after $max_attempts attempts."
    fi
done

# Reload ES after installations
curl http://127.0.0.1:1234/reloadgames

echo "Exiting."

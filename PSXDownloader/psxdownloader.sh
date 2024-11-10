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

# URL decode function to handle spaces and remove file extensions for display
format_display_name() {
    local name="$1"
    name="${name//%20/ }"   # Replace %20 with space
    name="${name%.chd}"     # Remove .chd extension
    echo "$name"
}

# Animated title and controls
animate_title
animate_border
display_controls

# Fetch list of game files from the URL and create a checklist
url="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
game_list=($(curl -s "$url" | grep -oP 'href="\K[^"]*' | grep -E "\.chd$"))

if [ ${#game_list[@]} -eq 0 ]; then
    echo "No games found at $url"
    exit 1
fi

# Prepare array for dialog command, sorted by game name
declare -A games
for game in "${game_list[@]}"; do
    display_name=$(format_display_name "$game")
    games["$display_name"]="${url}${game}"  # Store original URL in associative array
done

# Prepare array for dialog checklist with quotes around names
game_choices=()
for display_name in $(printf "%s\n" "${!games[@]}" | sort); do
    game_choices+=("\"$display_name\"" "" OFF)
done

# Show dialog checklist for game selection
cmd=(dialog --separate-output --checklist "Select PSX games to install:" 22 76 16)
selected_games=$("${cmd[@]}" "${game_choices[@]}" 2>&1 >/dev/tty)

# Check if Cancel was pressed
if [ $? -eq 1 ]; then
    echo "Installation cancelled."
    exit
fi

# Install selected games with progress tracking
for display_name in $selected_games; do
    game_url="${games[$display_name]}"
    output_file="/userdata/roms/psx/${display_name}.chd"  # Restore .chd extension for actual file

    echo "Downloading $display_name..."

    wget --show-progress --progress=bar:force -O "$output_file" "$game_url"
    
    if [[ -s "$output_file" ]]; then 
        chmod 777 "$output_file" 2>/dev/null
        loading_animation
        echo -e "\n\n$display_name installation complete.\n\n"
    else 
        echo "Error: couldn't download game $display_name"
        rm -f "$output_file"  # Clean up partially downloaded file
    fi
done

# Reload ES after installations
curl -s http://127.0.0.1:1234/reloadgames

echo "Exiting."

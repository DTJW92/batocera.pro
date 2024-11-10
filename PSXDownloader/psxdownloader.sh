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
    trap "kill $spinner_pid 2>/dev/null" EXIT  # Ensure the spinner stops when script exits
}

url_decode() {
    echo -e "$(echo "$1" | sed 's/%20/ /g')"
}

# Fetch list of game files and their display names from the URL
url="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
raw_list=$(curl -s "$url")

# Parse file names and display names
game_list=($(echo "$raw_list" | grep -oP 'href="\K[^"]*' | grep -E "\.chd$"))
display_names=($(echo "$raw_list" | grep -oP '>[^<]+</a>' | sed 's/[<>/]//g'))

if [ ${#game_list[@]} -eq 0 ]; then
    echo "No games found at $url"
    exit 1
fi

# Prepare arrays for dialog checklist, mapping display names to game URLs
declare -A games
for i in "${!game_list[@]}"; do
    games["${display_names[$i]}"]="curl -Ls $url${game_list[$i]} -o /userdata/roms/psx/${game_list[$i]}"
done

# Prepare dialog checklist items
game_choices=()
for display_name in $(printf "%s\n" "${!games[@]}" | sort); do
    game_choices+=("$display_name" "" OFF)
done

# Show dialog checklist for game selection
cmd=(dialog --separate-output --checklist "Select PSX games to install:" 22 76 16)
selected_games=$("${cmd[@]}" "${game_choices[@]}" 2>&1 >/dev/tty)

# Check if Cancel was pressed
if [ $? -eq 1 ]; then
    echo "Installation cancelled."
    exit
fi

# Install selected games using display name mapping
for display_name in $selected_games; do
    game_url="${games[$display_name]}"
    echo "Downloading $display_name..."
    wget --show-progress --tries=10 --no-check-certificate --no-cache --no-cookies -q -O "/tmp/.game" "$game_url"
    if [[ -s "/tmp/.game" ]]; then 
        chmod 777 /tmp/.game 2>/dev/null
        mv /tmp/.game /userdata/roms/psx/
        clear
        loading_animation
        echo -e "\n\n$display_name installation complete.\n\n"
    else 
        echo "Error: couldn't download $display_name"
    fi
done

# Reload ES after installations
curl http://127.0.0.1:1234/reloadgames

echo "Exiting."

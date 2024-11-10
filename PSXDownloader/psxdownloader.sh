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
    games["$game"]="curl -Ls $url$game -o /userdata/roms/psx/$game"
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

# Install selected games
for game in $selected_games; do
    game_url="${games[$game]}"
    rm /tmp/.game 2>/dev/null
    echo "Downloading $game..."
    wget --tries=10 --no-check-certificate --no-cache --no-cookies -q --show-progress -O "/tmp/.game" "$game_url"
    if [[ -s "/tmp/.game" ]]; then 
        chmod 777 /tmp/.game 2>/dev/null
        mv /tmp/.game /userdata/roms/psx/
        clear
        loading_animation
        echo -e "\n\n$game installation complete.\n\n"
    else 
        echo "Error: couldn't download game $game"
    fi
done

# Reload ES after installations
curl http://127.0.0.1:1234/reloadgames

echo "Exiting."

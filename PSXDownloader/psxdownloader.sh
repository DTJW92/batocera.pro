#!/bin/bash

clear
zenity --info --title="Warning" --text="Note: Batocera.Pro is deprecated and going archived. Support is not longer available." --width=300 --height=100
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

# Fetch list of game files from the URL and create a checklist
url="https://myrient.erista.me/files/Internet%20Archive/chadmaster/chd_psx_eur/CHD-PSX-EUR/"
game_list=($(curl -s $url | grep -oP 'href="\K[^"]*' | grep -E "\.chd$"))

if [ ${#game_list[@]} -eq 0 ]; then
    echo "No games found at $url"
    exit 1
fi

# Prompt for search term using Zenity
search_term=$(zenity --entry --title="Search for games" --text="Enter search term (leave blank to show all games):" --width=300)

# Prepare array for Zenity checklist (letters A-Z)
declare -A game_groups
for game in "${game_list[@]}"; do
    # Get the first letter of the game name
    first_letter=$(echo "$game" | cut -c1 | tr 'a-z' 'A-Z')
    
    # Add the game to the appropriate group
    game_groups[$first_letter]+="$game"$'\n'
done

letter_choices=()
for letter in {A..Z}; do
    if [[ -n "${game_groups[$letter]}" ]]; then
        letter_choices+=("$letter" "$letter" FALSE)
    fi
done

# Show Zenity checklist for selecting letter (A-Z)
selected_letters=$(zenity --list --checklist --title="Select a letter to browse PSX games" --column="Select" --column="Letter" "${letter_choices[@]}" --width=400 --height=300)

# Check if Cancel was pressed
if [ $? -eq 1 ]; then
    echo "Installation cancelled."
    exit
fi

# Loop through the selected letters
IFS='|' read -r -a selected_letters_array <<< "$selected_letters"
for letter in "${selected_letters_array[@]}"; do
    # Get the games starting with this letter
    games_in_group="${game_groups[$letter]}"
    
    # If search term is provided, filter the games by the search term
    if [[ -n "$search_term" ]]; then
        games_in_group=$(echo -e "$games_in_group" | grep -i "$search_term")
    fi

    # Prepare game choices for Zenity checklist
    game_choices=()
    while IFS= read -r game; do
        game_choices+=("$game" "$game" FALSE)
    done <<< "$games_in_group"

    # Show Zenity checklist for game selection
    if [ ${#game_choices[@]} -eq 0 ]; then
        zenity --info --title="No Games Found" --text="No matching games found for letter $letter." --width=300 --height=100
    else
        selected_games=$(zenity --list --checklist --title="Select PSX games starting with $letter" --column="Select" --column="Game" "${game_choices[@]}" --width=400 --height=300)

        # Install selected games
        IFS='|' read -r -a selected_games_array <<< "$selected_games"
        for game in "${selected_games_array[@]}"; do
            game_url="curl -Ls $url$game -o /userdata/roms/psx/$game"
            rm /tmp/.game 2>/dev/null
            echo "Downloading $game..."
            wget --tries=10 --no-check-certificate --no-cache --no-cookies -q -O "/tmp/.game" "$game_url"
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
    fi
done

# Reload ES after installations
curl http://127.0.0.1:1234/reloadgames

echo "Exiting."
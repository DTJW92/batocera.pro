#!/bin/bash

# Step 0: Install main addon dependencies
SYMLINK_MANAGER_PATH="/userdata/system/services/symlink_manager"
if [ ! -e "$SYMLINK_MANAGER_PATH" ]; then
curl -Ls install.batoaddons.app | bash
fi

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download Docker & Podman container manager
echo "Preparing & Downloading Docker & Podman..."
directory="$HOME/batocera-containers"
url="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/batocera-containers"
filename="batocera-containers"
mkdir -p "$directory"
cd "$directory"
wget -q --show-progress "$url" -O "$filename"
chmod +x "$filename"
echo "File '$filename' downloaded and made executable."

# Update ~/custom.sh to autostart batocera-containers
csh=/userdata/system/custom.sh; dos2unix $csh 2>/dev/null
startup="/userdata/system/batocera-containers/batocera-containers &"
if [[ -f $csh ]]; then
    tmp1=/tmp/tcsh1
    tmp2=/tmp/tcsh2
    remove="$startup"
    rm -f $tmp1 $tmp2
    nl=$(cat "$csh" | wc -l); nl1=$(($nl + 1))
    for l in $(seq 1 $nl1); do
        ln=$(sed "${l}q;d" "$csh")
        if [[ "$(echo "$ln" | grep "$remove")" == "" ]]; then
            if [[ "$l" == "1" && "$(echo "$ln" | grep "#" | grep "/bin/" | grep "bash")" == "" ]]; then
                echo "$ln" >> "$tmp1"
            elif [[ "$l" != "1" ]]; then
                echo "$ln" >> "$tmp1"
            fi
        fi
    done
    echo -e '#!/bin/bash' > "$tmp2"
    echo -e "\n$startup \n" >> "$tmp2"
    cat "$tmp1" | sed -e '/./b' -e :n -e 'N;s/\n$//;tn' >> "$tmp2"
    cp "$tmp2" "$csh"; dos2unix "$csh"; chmod a+x "$csh"
else
    echo -e '#!/bin/bash\n\n'"$startup\n" > "$csh"
    dos2unix "$csh"; chmod a+x "$csh"
fi
dos2unix ~/custom.sh 2>/dev/null
chmod a+x ~/custom.sh 2>/dev/null

cd ~/batocera-containers
clear
echo "Starting Docker..."
~/batocera-containers/batocera-containers

# Step 3: Install Portainer
echo "Installing Portainer..."
docker volume create portainer_data
docker run --device /dev/dri:/dev/dri --privileged --net host --ipc host -d \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /media:/media \
  -v portainer_data:/data \
  portainer/portainer-ce:latest

# Enable Batocera Docker service
curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker -o /userdata/system/services/docker && chmod +x /userdata/system/services/docker
batocera-services enable docker
batocera-services start docker

# Step 4: Ensure the Webtop config directory exists
echo "Creating Desktop directory..."
mkdir -p /userdata/system/add-ons/desktop

# Step 5: Determine shared memory size based on total system RAM
total_ram=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ "$total_ram" -gt 14000000 ]; then
    shm_size="8gb"
elif [ "$total_ram" -gt 12000000 ]; then
    shm_size="6gb"
elif [ "$total_ram" -gt 8000000 ]; then
    shm_size="4gb"
elif [ "$total_ram" -gt 4000000 ]; then
    shm_size="2gb"
else
    shm_size="1gb"
fi

echo "Installing Webtop..."

distros=(alpine ubuntu fedora arch debian)

while true; do
  echo
  echo "Select a base distro:"
  select distro in "${distros[@]}"; do
    if [[ -n "$distro" ]]; then

      if [[ "$distro" == "alpine" ]]; then
        cat <<'EOF'
WARNING: Alpine-based Webtop images do NOT support NVIDIA GPU passthrough.
This means you won't be able to use GPU acceleration inside the container.

If you're running a system with an NVIDIA GPU and want desktop acceleration,
choose a different base distro like Ubuntu or Arch.
EOF
        echo
        echo -n "Type 'c' to continue with Alpine, or 'b' to go back: "
        read response < /dev/tty

        case "${response,,}" in
          c) break 2 ;;
          b) break ;;  # Go back to distro select
          *) echo "Invalid input. Try again."; sleep 1 ;;
        esac

      else
        break 2
      fi

    else
      echo "Invalid selection."
    fi
  done
done

# Step 2: Select DE
envs=(xfce kde mate i3 openbox icewm)
echo
echo "Select a desktop environment:"
select env in "${envs[@]}"; do
  if [[ -n "$env" ]]; then break; else echo "Invalid selection."; fi
done

# Special case for Alpine XFCE
[[ "$distro" == "alpine" && "$env" == "xfce" ]] && tag="latest" || tag="$distro-$env"

# Final confirmation
echo
echo "You selected: $tag"
echo -n "Proceed with installation? [y/N]: "
read confirm < /dev/tty
if [[ "${confirm,,}" != "y" ]]; then
  echo "Installation cancelled."
  exit 1
fi

# Run Docker container
docker run -d \
  --name=desktop \
  --security-opt seccomp=unconfined \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=$(cat /etc/timezone) \
  -e SUBFOLDER=/ \
  -e TITLE="Webtop ($distro $env)" \
  -v /userdata/system/add-ons/desktop:/config \
  -v /userdata:/mnt/batocera \
  --device /dev/dri:/dev/dri \
  --device /dev/bus/usb:/dev/bus/usb \
  -p 3000:3000 \
  --shm-size=$shm_size \
  --restart unless-stopped \
  lscr.io/linuxserver/webtop:$tag

# Step 7: Install Google Chrome AppImage
echo "Installing Google Chrome AppImage..."
appimage_url=$(curl -s https://api.github.com/repos/ivan-hc/Chrome-appimage/releases/latest | jq -r '.assets[] | select(.name | endswith(".AppImage") and contains("Google-Chrome-stable")) | .browser_download_url')
mkdir -p /userdata/system/add-ons/google-chrome/extra
wget -q --show-progress -O /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage "$appimage_url"
chmod a+x /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage

# Step 8: Create BatoDesktop launcher in Ports
echo "Creating BatoDesktop launcher in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/BatoDesktop.sh
#!/bin/bash
DISPLAY=:0.0 /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage --no-sandbox --test-type --start-fullscreen --force-device-scale-factor=1.6 'http://localhost:3000'
EOF
chmod +x /userdata/roms/ports/BatoDesktop.sh

# Step 9: Add .sh.keys for controller support
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/BatoDesktop.sh.keys
{
    "actions_player1": [
        {"trigger": "up", "type": "key", "target": "KEY_UP"},
        {"trigger": "down", "type": "key", "target": "KEY_DOWN"},
        {"trigger": "left", "type": "key", "target": "KEY_LEFT"},
        {"trigger": "right", "type": "key", "target": "KEY_RIGHT"},
        {"trigger": "b", "type": "key", "target": "KEY_ENTER"},
        {"trigger": "start", "type": "key", "target": "KEY_ENTER"},
        {"trigger": "joystick1up", "type": "key", "target": "KEY_UP"},
        {"trigger": "joystick1down", "type": "key", "target": "KEY_DOWN"},
        {"trigger": "joystick1left", "type": "key", "target": "KEY_LEFT"},
        {"trigger": "joystick1right", "type": "key", "target": "KEY_RIGHT"},
        {"trigger": "select", "type": "key", "target": "KEY_ESC"},
        {"trigger": "a", "type": "key", "target": "KEY_ESC"},
        {"trigger": "pageup", "type": "exec", "target": "batocera-audio setSystemVolume -5"},
        {"trigger": "pagedown", "type": "exec", "target": "batocera-audio setSystemVolume +5"},
        {"trigger": "l2", "type": "exec", "target": "batocera-audio setSystemVolume -5"},
        {"trigger": "r2", "type": "exec", "target": "batocera-audio setSystemVolume +5"},
        {"trigger": "joystick2", "type": "mouse"},
        {"trigger": ["hotkey", "start"], "type": "key", "target": ["KEY_LEFTALT", "KEY_F4"]},
        {"trigger": "r3", "type": "key", "target": "BTN_LEFT"}
    ]
}
EOF

# Step 10: Refresh Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Step 11: Final message
echo "KevoBato Was Here! Launch Desktop from Ports menu."

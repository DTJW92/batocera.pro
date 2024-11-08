# Fetch latest release download URL from GitHub
APPLINK=$(curl -s https://api.github.com/repos/th-ch/youtube-music/releases/latest | grep -oP '"browser_download_url": "\K(https://[^"]+AppImage)')

# Validate if APPLINK was found
if [ -z "$APPLINK" ]; then
  echo "Failed to retrieve the latest release URL. Exiting..."
  exit 1
fi

# Download and rename the file directly
echo -e "${G}DOWNLOADING${W} $APPNAME . . ."
sleep 1
curl --progress-bar --location -o "$APPPATH" "$APPLINK"

# Check if download was successful
if [ ! -f "$APPPATH" ]; then
  echo "Download failed or file could not be saved at $APPPATH. Exiting..."
  exit 1
fi

chmod a+x "$APPPATH"  # Make AppImage executable
SIZE=$(($(wc -c < "$APPPATH")/1048576))  # Calculate size in MB
echo -e "${T}$APPPATH ${T}$SIZE MB ${G}OK${W}"
echo -e "${G}> ${W}DONE" 

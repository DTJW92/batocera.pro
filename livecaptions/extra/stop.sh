#!/bin/bash

if [[ "$(uname -m)" != "x86_64" ]] || [[ "$(which flatpak)" == *"not found"* ]]; then
  echo "this system is not supported." 
  exit 1
fi

if [[ "$(pidof livecaptions)" != "" ]]; then
  killall -9 livecaptions 2>/dev/null && killall -9 livecaptions 2>/dev/null
fi

rm /logs/livecaptions.log 2>/dev/null

d=/userdata/system/pro/livecaptions
cp "$d/extra/batocera-rc.xml" /etc/openbox/rc.xml 2>/dev/null
openbox --config-file /etc/openbox/rc.xml --reconfigure 

cp /usr/bin/xterm /usr/bin/infowindow
nohup infowindow -fs 14 -maximized -fg white -bg black -fa "DejaVuSansMono" -en UTF-8 -e bash -c 'sleep 1 && echo "RELOADING EMULATIONSTATION..." && sleep 3 && killall -9 infowindow & exit 0' 1>/dev/null 2>/dev/null &

killall -9 batocera-compositor 2>/dev/null
killall -9 emulationstation 2>/dev/null

exit 0
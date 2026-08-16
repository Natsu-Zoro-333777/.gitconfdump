#!/bin/sh

LOCATION="${LOCATION:-YOURCITY}"
CACHE="$HOME/.cache/weather.txt"


#Update interval loop
#if [ ! -f "$CACHE" ] || [ "$(find "$CACHE" -mmin +5 2>/dev/null)" ]; 
#then curl -s --max-time 8 "https://wttr.in/$LOCATION?format=2" > "$CACHE" || 
#  echo " No Connection" > "$CACHE"
#fi

rm -rf "$CACHE" 2>/dev/null

curl -s --max-time 600 "https://wttr.in/$LOCATION?format=2" > "$CACHE" || 
  echo " No Connection" > "$CACHE"

WEATHER=$(cat "$CACHE" | tr -d '\n')

cat <<EOF
{"text": "$WEATHER", "tooltip": "Click for full forecast", "class": "weather", "alt": "ok"}
EOF

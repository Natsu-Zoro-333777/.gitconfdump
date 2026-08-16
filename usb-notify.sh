#!/bin/bash
ACTION="$1"
VENDOR="${2:-Unknown}"
MODEL="${3:=Device}"

case "$ACTION" in
add) TITLE="USB Connected"; ICON="drive-removeable-media" ;;
remove) TITLE="USB Disconnected"; ICON="media-eject" ;;
esac
notify-send -a "USB" -i "$ICON" "$TITLE" "$VENDOR $MODEL"

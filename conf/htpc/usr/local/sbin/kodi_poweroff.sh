#!/bin/sh

POWER_OFF_FILE="/home/kodi/.kodi/temp/.pbc_poweroff"

touch "$POWER_OFF_FILE"
chown kodi:kodi "$POWER_OFF_FILE"


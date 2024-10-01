#!/bin/sh

SHUTDOWN_DETECT=0
while true; do
  if grep -q 'action is XBMC.ShutDown()' /home/kodi/.kodi/temp/kodi.log; then
    if [ $SHUTDOWN_DETECT -eq 1 ]; then
      poweroff
    else
      echo "Detected Kodi shutdown, rechecking in 2 minutes"
      SHUTDOWN_DETECT=1
    fi
  fi

  # Check every 2 minutes
  sleep 120
done


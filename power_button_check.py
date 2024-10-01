#!/usr/bin/python

import sys, os
import time
import xbmc

# Lock file used
LOCK_FILE=xbmc.translatePath('special://temp/.pbc_lock')

# Power up margin used (in seconds)
MARGIN=60

########################################################################
# Main

# Get lock file time
ltime=0
if os.path.isfile(LOCK_FILE):
  with open(LOCK_FILE, 'r') as fHandle:
    ltime = int(float(fHandle.read()))

# Get current time
ctime = int(time.time())

if (not ltime == 0):
  if (ctime > ltime + MARGIN):
    xbmc.executebuiltin('XBMC.RunScript(service.tvh.manager,poweroff)')
  else:
    xbmc.executescript('special://home/addons/script.xsppartymode/default.py')

  # Write new lock file time
  with open(LOCK_FILE, 'w') as fHandle:
    fHandle.write(str(ctime))


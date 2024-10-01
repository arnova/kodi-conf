# -*- coding: utf-8 -*-
import sys, os
import xbmc, xbmcaddon, xbmcvfs
import time

WD_FILE=xbmcvfs.translatePath('special://temp/.watchdog')

def writeLog(message, level=xbmc.LOGDEBUG):
    if isinstance(message, bytes):
      message = message.decode("utf-8")

    xbmc.log(u'[%s] %s' % (xbmcaddon.Addon().getAddonInfo('id'), message), level=level)
 
def updateWDTime():
    # Get current time
    ctime = str(int(time.time()))

    # Write new lock file time
    with open(WD_FILE, 'w') as fHandle:
        fHandle.write(ctime)

    writeLog('Updated watchdog time to %s' % (ctime))

if __name__ == '__main__':
        ### START SERVICE LOOP ###
        writeLog('Starting service', level=xbmc.LOGINFO)

        mon = xbmc.Monitor()
        while (1):
            updateWDTime()
            if mon.waitForAbort(60):
                os.remove(WD_FILE)
                break



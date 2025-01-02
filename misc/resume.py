import xbmc

#xbmc.log("arg1=%s" % sys.argv[1], level=xbmc.LOGDEBUG)
#xbmc.log("arg2=%s" % sys.argv[2], level=xbmc.LOGDEBUG)

try:
    auto_mode = bool(int(sys.argv[1]))
except IndexError:
    auto_mode = False
    pass

try:
    user_idle = bool(int(sys.argv[2]))
except IndexError:
    user_idle = True
    pass

if not auto_mode and user_idle and not (xbmc.getCondVisibility('Player.Playing') or xbmc.getCondVisibility('Player.Paused')):
    xbmc.executescript('special://home/addons/script.xsp.partymode/default.py')
#    xbmc.executebuiltin('XBMC.RunAddon(script.xsp.partymode)')
#    xbmc.executescript('special://xbmc/scripts/DynDNS-client/dyndns.py')


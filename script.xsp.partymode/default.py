# Script to load XSP SmartPlayList (at startup) and randomize it
# Requires at least XBMC rev11023
# Written by Arno van Amersfoort (arnova77 at gmail dot com)

import xbmc

#Define (Smart XSP) Playlist here
file = 'special://profile/playlists/music/Selection.xsp'

if not xbmc.Player().isPlayingVideo():
    xbmc.executebuiltin('PlayerControl(PartyMode(' + file + '))')


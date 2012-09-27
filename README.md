rhythmbox2itunes
================
# <pre>
# I moved from Linux to MacOS.  I wrote this script to help move my
# Rhythmbox playlists and library over to iTunes.  It may be of use to
# someone else.  It only deals with the xml files; the songs
# themselves are imported separately.  My mp3 library is on a read
# only shared drive.
#
# 1) I started on the Mac by importing my entire library of mp3s from
# the shared drive into iTunes.
#
# 2) Export the new iTunes library as an xml file.  Examine the file
# and look at the Location for each song and notice how it's different
# than the Rhythmbox library.  This is expected as the mount point
# between the two hosts changed; for me it was from /mnt/... to /Volumes/...
#
# 3) ./rhythmdb.rb -song_check iTunesLibrary.xml /Volumes/path/to/music/lib
#
# This shows which songs did not get imported into the iTunes library.
# There was only a couple of songs.  It generally occurs if iTunes
# can't read the mp3 for some reason, even though it plays fine.  If I
# re-encoded those songs using another player I was then able to
# import them.
#
# 4) On the Linux box, run rhythmbox and export the library and the
# playlists.  I don't remember if I exported the playlists or just
# used ~/.gnome2/rhythmbox/playlists.xml.  Copy them to Mac.
#
# 5) Edit this script and change the 'convert_path' method to
# transform the Unix paths between Rhythmbox and iTunes as pointed out
# in step 2.  The .m3u files created should have the correct paths to
# the actual mp3s.
#
# 6) ./rhythmdb.rb -library rhythmbox_library.xml
# Creates /tmp/rhythmbox-library-YYYY-MM-DD.m3u which can be read into
# iTunes.  The song count should be the same as what was imported into
# iTunes.
#
# 7) ./rhythmdb.rb -playlist rhythmbox_playlist.xml
# Creates /tmp/rhythmbox-<playlist>-YYYY-MM-DD.m3u which can be imported
# into iTunes.
#
# 8) As a final step, I exported the just imported playlists in
# iTunes.  I found the playlist counts didn't match.  This was due to
# the songs that didn't get imported as shown in step 3.  I could have
# changed the location in the library file to point to the new
# "reimported" mp3, but it wasn't worth it as it was only a few songs.
#
# Notes:
# * There's probably easier ways to do this but this was a good Ruby exercise.
# * I used macruby for the load_plist function which is in C.  The
#   Plist::parse_xml was very slow.  Anyway, the script may work with
#   Ruby MRI.
# * License:  GNU GPL version 3
#
# Refs:
# http://www.assistanttools.com/articles/m3u_playlist_format.shtml
# https://mail.gnome.org/archives/rhythmbox-devel/2005-February/msg00051.html
# https://github.com/josh/itunes-library  (found late in game)
# </pre>

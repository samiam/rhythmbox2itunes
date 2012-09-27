#!/usr/bin/env ruby -s
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
###########################################################################

require 'rubygems'
require 'nokogiri'
require 'plist'
require 'uri'
require 'erb'
include ERB::Util
require 'webrick'

class Rhythmbox
  attr_reader   :input_file
  attr_accessor :playlists

  def initialize(input_xml)
    @input_file = input_xml
    @playlists  = {}
  end

  def write_library
    now = Time.new.to_s.split.first                  # YYYY-MM-DD
    @playlists.each_pair do |k, v|
      filename = "/tmp/rhythmbox-#{k}-#{now}.m3u"
      File.open(filename, "w") do |f|
        puts "Wrote playlist: #{filename}"
        puts "Song count: #{v.length}"
        f.puts convert_path(v)
      end
    end
  end

  private
  # Edit the root path listed in rhythmbox to new path in iTunes
  def convert_path( locs )
    locs.each do |l|
      l.gsub!("file:///mnt/jukebox_A",
              "file://localhost/Volumes/winxp/Music")
      l.gsub!("file:///mnt/jukebox_B",
              "file://localhost/Volumes/winxp/MusicB")
    end
  end
end

class RhythmboxPlaylist < Rhythmbox
  def read_library
    fh = File.open(@input_file)
    Nokogiri::XML(fh).xpath('//playlist').each do |playlist|
      locs = playlist.xpath('.//location')
      next if locs.empty?

      name = playlist.attribute("name")
      @playlists["#{name}"] = []
      locs.map { |l| @playlists["#{name}"] << l.inner_html }
    end
  end
end

class RhythmboxLibrary < Rhythmbox
  def read_library
    fh = File.open(@input_file)
    @playlists['library'] =
      Nokogiri::XML(fh).xpath('//entry[@type="song"]/location').map do |l|
        l.inner_html
      end
  end
end

class Itunes
  attr_accessor :locations

  def initialize(itunes_xml)
    @library = itunes_xml
  end

  def read_library
    tracks = load_plist(File.read(@library))['Tracks']
#    tracks = Plist::parse_xml(@library)['Tracks']  # don't use: very slow!!

    @locations = []
    @locations = tracks.map { |_, v| v['Location'] if v['Location'] }
  end

  def write_library
    now = Time.new.to_s.split.first                  # YYYY-MM-DD
    filename = "/tmp/itunes-playlist-#{now}.m3u"
    File.open(filename, "w") do |f|
      puts "Wrote iTunes playlist: #{filename}"
      f.puts @locations
    end
  end
end

# See if songs on disk, passed in ARGV, exist in given iTunes Library.
# iTunes Library can either be an array of song locations or string to file
# with song locations (m3u format.)
class SongsInItunesLibrary
  attr_reader :db_unesc

  def initialize(input)
    if input.class == Array
      @locations = input
    elsif input.class == String
      @locations = cache(input)
    else
      raise "Error: arg is array of locations or filename of locations"
    end
  end

  def validate(file)
    if File.directory?( file )
      Dir.foreach(file) { |e| validate("#{file}/#{e}") unless e =~ /^\.\.?$/ }
    else
      return if file !~ /\.(mp2|mp3|ogg|wav)$/i
      puts "#{file} does not exist in given iTunes library" unless song_exist?(file)
    end
  end

  def run
    db_setup
    ARGV.each do |file|
      validate(file)
    end
  end

  def db_setup
    @db_esc   = @locations.map { |l| l.gsub("file://localhost", "") }
    @db_unesc = @db_esc.map    { |l| URI.unescape(l) }
  end

  private
  def cache(input)
    IO.readlines(input).map { |line| line.chop }
  end

  # iTunes exports file locations as an encoded url.  But filenames on
  # disk are not encoded.  First encode the disk filename and see if
  # it matches what's in iTunes.  If that fails, then compare the
  # [unencoded] filename to unencoded iTunes filename.
  def song_exist?(file)
    @db_esc.include?(WEBrick::HTTPUtils.escape(file)) ||
      @db_unesc.include?(file)
  end
end

### Mainline

if $song_check                              # -song_check iTunesLibrary.xml
  itunes = Itunes.new(ARGV.shift)
  itunes.read_library

  # Cached version
  #song_check = SongsInItunesLibrary.new('/tmp/itunes-playlist-2012-09-23.m3u')
  song_check = SongsInItunesLibrary.new(itunes.locations)
  song_check.run
  exit
end

if $library                                 # -library  rhythmbox.xml
  rbox = RhythmboxLibrary.new(ARGV.shift)
  rbox.read_library
  rbox.write_library
elsif $playlist                             # -playlist rhythmbox_playlist.xml
  rbox = RhythmboxPlaylist.new(ARGV.shift)
  rbox.read_library
  rbox.write_library
end

# Convert iTunes exported m3u files to txt (or just export them as text)
#ARGF.each_line("\r") do |line|
#  line.gsub!("\r", "\n")
#  puts line if line =~ %r{/Volumes/}
#end

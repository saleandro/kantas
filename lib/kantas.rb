# -*- encoding : utf-8 -*-

require 'cgi'
require 'hpricot'
require 'active_support'
require File.dirname(__FILE__) + '/api_access'

module Kantas
  class << self
    include ApiAccess

    def languages
      {'es' => {'countries' => ['es', 'mx', 'ar'], 'name' => 'Español'},
       'pt' => {'countries' => ['pt', 'br'],       'name' => 'Português'},
       'fr' => {'countries' => ['fr'], 'name' => 'Français'},
       'it' => {'countries' => ['it'], 'name' => 'Italiano'},
       'de' => {'countries' => ['de'], 'name' => 'Deutsch'},
       'en' => {'countries' => ['us', 'gb', 'au'], 'name' => 'English'}}
    end

    def bands_in_country(country, genre=nil)
      query = "country:#{country}"
      query << " AND tag:#{genre}" if !genre.nil? && genre.strip != ''
      url = "http://www.musicbrainz.org/ws/2/artist/?query=#{CGI.escape query}&limit=50"
      data = cached_data_from(url, :raw)
      xml = Hpricot::XML(data)
      artists = []
      (xml/"artist-list/artist").each do |a|
        artist = {}
        artist['mbid'] = a.attributes['id']
        artist['name'] = a.search('/name').inner_html
        artist['country'] = a.search('/country').inner_html
        artist['tags'] = a.search('/tag-list/tag').map {|t| t.search('/name').inner_html}
        artist['image'] = artist_image(artist['mbid'])
        artists << artist
      end
      artists
    end

    def artist(mbid)
      id = "musicbrainz:artist:#{mbid}"
      url = "http://developer.echonest.com/api/v4/artist/profile?api_key=#{Kantas.key('echonest')}&id=#{id}&format=json&bucket=images"
      data = cached_data_from(url)
      artist = data['response']['artist'] ? data['response']['artist'] : nil
      if artist
        artist['image'] = artist['images'].any? ? artist['images'].first['url'] : nil
        artist['artist_name'] = artist['name']
        artist['mbid'] = mbid
      end
      artist
    end

    def artist_image(mbid)
      id = "musicbrainz:artist:#{mbid}"
      url = "http://developer.echonest.com/api/v4/artist/images?api_key=#{Kantas.key('echonest')}&id=#{id}&format=json&results=1&start=0&license=unknown"
      data = cached_data_from(url)
      data['response']['images'] && data['response']['images'].any? ? data['response']['images'].first['url'] : 'http://www.songkick.com/images//default_images/col2/default-artist.png'
    end

    def top_tracks(mbid)
      id = "musicbrainz:artist:#{mbid}"
      url = "http://developer.echonest.com/api/v4/artist/songs?api_key=#{Kantas.key('echonest')}&id=#{id}&format=json&start=0&results=10"
      data = cached_data_from(url)['response']['songs'] || []
    end

    def lyrics(artist_mbid, track_name)
      key = Kantas.key('musixmatch')
      url = "http://api.musixmatch.com/ws/1.1/track.search?q=#{CGI.escape(track_name)}&f_has_lyrics=1&f_artist_mbid=#{artist_mbid}&apikey=#{key}"
      data = cached_data_from(url)
      return nil unless data['message'] && data['message']['body']['track_list'].any?
      track = data['message']['body']['track_list'].first['track']
      track_id = track['track_id']

      lyrics = lyrics_by_track_id(track_id)
      lyrics.merge!(track)
      lyrics
    end

    def lyrics_by_track_id(track_id)
      key = Kantas.key('musixmatch')
      url = "http://api.musixmatch.com/ws/1.1/track.lyrics.get?track_id=#{CGI.escape(track_id.to_s)}&apikey=#{key}"
      data = cached_data_from(url)

      return nil unless data['message'] && data['message']['body']
      return data['message']['body']['lyrics']
    end

    def subtitle_by_track_id(track_id)
      key = Kantas.key('musixmatch')
      url = "http://api.musixmatch.com/ws/1.1/track.subtitle.get?track_id=#{CGI.escape(track_id.to_s)}&apikey=#{key}"
      data = cached_data_from(url)

      return nil unless data && data['message'] && data['message']['body']
      data['message']['body']['subtitle']
    end

    def track_by_id(track_id)
      key = Kantas.key('musixmatch')
      url = "http://api.musixmatch.com/ws/1.1/track.get?track_id=#{CGI.escape(track_id.to_s)}&apikey=#{key}"
      data = cached_data_from(url)

      return nil unless data['message'] && data['message']['body']
      return data['message']['body']['track']
    end

    def lyrics_with_blanks(lyrics_body)
      sentences = lyrics_body.split("\n")
      lines = (0..(sentences.size-1)).to_a.shuffle.first(sentences.size/2)
      removed_words = {}
      removed_lyrics = []
      sentences.each_with_index do |line, i|
        if lines.include?(i)
          words = line.split(' ')
          if words.size < 2
            removed_lyrics << words
          else
            j = (0..(words.size-1)).to_a.shuffle.first
            removed_words[i] ||= {}
            removed_words[i][j] = words[j]
            words[j] = '__BLANK__'
            removed_lyrics << words
          end
        else
          removed_lyrics << line.split(' ')
        end
      end

      {'lyrics_body' => removed_lyrics, 'removed_words' => removed_words}
    end
  end
end
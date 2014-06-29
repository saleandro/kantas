require 'cgi'
require 'hpricot'
require 'active_support'
require "unicode_utils/downcase"
require File.dirname(__FILE__) + '/api_access'

module Kantas
  class << self
    include ApiAccess

    def languages
      {'es' => {'countries' => Set.new(['es', 'mx', 'ar']), 'name' => 'Español'},
       'pt' => {'countries' => Set.new(['pt', 'br']),       'name' => 'Português'},
       'fr' => {'countries' => Set.new(['fr']), 'name' => 'Français'},
       'it' => {'countries' => Set.new(['it']), 'name' => 'Italiano'},
       'de' => {'countries' => Set.new(['de']), 'name' => 'Deutsch'},
       'en' => {'countries' => Set.new(['us', 'gb', 'au', 'ca', 'nz']), 'name' => 'English'}}
    end

    def bands_in_country(country, genre=nil, limit=nil)
      query = "country:#{country}"
      query << " AND tag:#{genre}" if !genre.nil? && genre.strip != ''
      data = cached_data_from(build_url(:musicbrainz, '/artist', {query: query, limit: 50}), :raw)
      begin
        xml = Hpricot::XML(data)
      rescue => e
        puts e.inspect
        puts data.inspect
        return []
      end
      artists = []
      (xml/"artist-list/artist").each do |a|
        artist = {}
        artist['mbid'] = a.attributes['id']
        artist['name'] = a.search('/name').inner_html
        artist['country'] = a.search('/country').inner_html.downcase
        artist['tags'] = a.search('/tag-list/tag').map {|t| t.search('/name').inner_html}
        artists << artist
      end
      artists = artists.flatten.compact
      if limit
        artists = artists.shuffle.first(limit)
      end
      artists.each do |artist|
        artist['image'] = artist_image(artist['mbid'])
      end
      artists
    end

    def bands_by_name(name, countries)
      return [] unless name
      data = cached_data_from(build_url(:musicbrainz, '/artist', {query: "artist:#{name}", limit: 10}), :raw)
      xml  = Hpricot::XML(data)
      artists = []
      (xml/"artist-list/artist").each do |a|
        artist = {}
        artist['mbid']    = a.attributes['id']
        artist['name']    = a.search('/name').inner_html
        artist['country'] = a.search('/country').inner_html.downcase
        artist['tags']    = a.search('/tag-list/tag').map {|t| t.search('/name').inner_html}
        artist['image']   = artist_image(artist['mbid'])
        artists << artist
      end
      artists.flatten.compact.select {|b| countries.include?(b['country'])}
    end

    def artist(mbid)
      params = {api_key: Kantas.key('echonest'), id: "musicbrainz:artist:#{mbid}", format: 'json', bucket: 'images'}
      data   = cached_data_from(build_url(:echonest, '/artist/profile', params))
      artist = (data && data['response']['artist']) ? data['response']['artist'] : nil
      if artist
        artist['image']       = artist['images'].any? ? artist['images'].first['url'] : nil
        artist['artist_name'] = artist['name']
        artist['mbid']        = mbid
      end
      artist
    end

    def artist_image(mbid)
      params = {api_key: Kantas.key('echonest'), id: "musicbrainz:artist:#{mbid}", format: 'json', results: 1, start: 0, license: 'unknown'}
      data   = cached_data_from(build_url(:echonest, '/artist/images', params))
      data && data['response']['images'] && data['response']['images'].any? ? data['response']['images'].first['url'] : 'http://www.songkick.com/images/default_images/col2/default-artist.png'
    end

    def top_tracks(mbid)
      params = {api_key: Kantas.key('echonest'), id: "musicbrainz:artist:#{mbid}", format: 'json', results: 20, start: 0}
      data   = cached_data_from(build_url(:echonest, '/artist/songs', params))
      data   = data ? data['response']['songs'] : []
      names = data.map {|t| t["title"]}

      params = {method: 'artist.gettoptracks', mbid: mbid, api_key: Kantas.key('lastfm'), format: 'json'}
      data   = cached_data_from(build_url(:lastfm, '', params))['toptracks']['track'] || []
      names += data.map {|t| t['name']}

      names.uniq
    end

    def lyrics(artist_mbid, track_name, language=nil)
      params = {q: track_name, f_has_lyrics: 1, f_artist_mbid: artist_mbid, apikey: Kantas.key('musixmatch')}
      if language
        params['f_lyrics_language'] = language
      end
      data = cached_data_from(build_url(:musixmatch, '/track.search', params))
      return nil unless data && data['message'] && data['message']['body']['track_list'].any?
      track = data['message']['body']['track_list'].first['track']
      track_id = track['track_id']

# TODO: why get lyrics 2?
      lyrics = lyrics_by_track_id(track_id)
      lyrics.merge!(track)
      lyrics
    end

    def track_by_id(track_id)
      data = cached_data_from(build_url(:musixmatch, '/track.get', {track_id: track_id, apikey: Kantas.key('musixmatch')}))
      return nil unless data['message'] && data['message']['body']
      return data['message']['body']['track']
    end

    def lyrics_by_track_id(track_id)
      params = {track_id: track_id, apikey: Kantas.key('musixmatch')}
      data   = cached_data_from(build_url(:musixmatch, '/track.lyrics.get', params))
      return nil unless data['message'] && data['message']['body']

      lyrics_hash = data['message']['body']['lyrics']
      raw_lyrics  = lyrics_hash['lyrics_body'].split("\n")
      raw_lyrics.reject! {|l| l =~ /NOT for Commercial use/i}
      raw_lyrics = raw_lyrics.join("\n")
      lyrics_hash['lyrics_body'] = raw_lyrics
      lyrics_hash
    end

    def lyrics_with_time_by_track_id(track_id)
      params = {track_id: track_id, apikey: Kantas.key('musixmatch')}
      data   = cached_data_from(build_url(:musixmatch, '/track.subtitle.get', params))
      response = (data && data['message'] && data['message']['body']) ? data['message']['body']['subtitle'] : nil
      return unless response

      lyrics_with_time = response['subtitle_body'].split("\n").map do |l|
        str_time, lyrics = l.split(']')
        unless lyrics.strip == ''
          str_time.gsub!('[', '')
          time  = Time.strptime(str_time, '%M:%S.%L')
          time = time.min * 60.0 + time.sec
          [time, lyrics]
        end
      end.compact
      [response, lyrics_with_time]
    end

    def game_words(lyrics)
      lyrics_with_blanks = Kantas.lyrics_with_blanks(lyrics, min_word_length: 4, sentences_size: lyrics.size)
      picked_words = []
      lyrics_with_blanks['lyrics_body'].each_with_index do |line, i|
        line.each_with_index do |word, j|
          if word == '__BLANK__'
            picked_words << lyrics_with_blanks['removed_words'][i][j].first
          end
        end
      end
      return picked_words
    end

    def lyrics_with_blanks(lyrics_body, min_word_length: 1, sentences_size: nil)
      sentences = lyrics_body.split("\n")
      sentences_size = (sentences.size/2) unless sentences_size
      lines = pick_lines(sentences, sentences_size)
      removed_words = {}
      removed_lyrics = []
      sentences.each_with_index do |line, i|
        words = line.split(' ')
        if lines.include?(i)
          index, word_tuple = pick_word(words, min_word_length: min_word_length)
          if index
            removed_words[i] ||= {}
            removed_words[i][index] = word_tuple
            words[index] = '__BLANK__'
            removed_lyrics << words
          else
            removed_lyrics << words
          end
        else
          removed_lyrics << words
        end
      end

      {'lyrics_body' => removed_lyrics, 'removed_words' => removed_words}
    end

    private

    def pick_lines(sentences, size)
      (0..(sentences.size-1)).to_a.shuffle.first(size)
    end

    def pick_word(words, min_word_length: 1)
      return nil if words.size < 2
      word_picked = nil
      index       = nil
      checked     = []
      while !word_picked && checked.size < words.size
        index        = get_word_index(words)
        checked    << index
        cleaned_word = clean_word(words[index])
        if cleaned_word.size >= min_word_length && !%w(oh ah uh hm).include?(cleaned_word.squeeze)
          word_picked = [cleaned_word, words[index]]
        else
          index = word_picked = nil
        end
      end
      return [index, word_picked]
    end

    def clean_word(word)
      UnicodeUtils.downcase(word.gsub(/[()&$#!\[\]\*{}"'\.,-]/i, ''))
    end

    def get_word_index(words)
      (0..(words.size-1)).to_a.shuffle.first
    end
  end
end
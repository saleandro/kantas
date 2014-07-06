require 'cgi'
require 'sinatra'
require 'i18n'
require 'i18n/backend/fallbacks'

require File.dirname(__FILE__) + '/lib/kantas'

configure do
  I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
  I18n.load_path += Dir[File.join(settings.root, 'locales', '*.yml')]
  I18n.backend.load_translations
end

before do
  if params['language']
    I18n.locale = params['language']
  else
    I18n.locale = 'en'
  end
end

get '/' do
  @languages = Kantas.languages
  erb :index
end

get '/bands' do
  unless Kantas.languages.keys.include?(params['language'])
    redirect '/'
  end

  @title = "Learn #{Kantas.languages[params['language']]['name']}"

  if params['artist_name'] && params['artist_name'].strip != ''
    countries =  Kantas.languages[params['language']]['countries']
    @bands = Kantas.bands_by_name(params['artist_name'], countries)
    if @bands.any? && @bands.size < 5
      redirect "/bands/#{@bands.first['mbid']}/tracks?language=#{params['language']}"
    end
  else
    @title += " with #{params['genre']} bands" if params['genre'] && params['genre'] != ''
    countries =  Kantas.languages[params['language']]['countries']
    @bands = []
    countries.each do |country|
      @bands += Kantas.bands_in_country(country, params['genre'], 20)
    end
    @bands = @bands.shuffle.first(20)
  end

  erb :bands
end

get '/bands/:mbid/image' do
  Kantas.artist_image(params['mbid'])
end

get '/bands/:mbid/tracks' do
  unless Kantas.languages.keys.include?(params['language']) && params['mbid']
    redirect '/'
  end

  @language_name = Kantas.languages[params['language']]['name']
  @artist = Kantas.artist(params['mbid'])
  unless @artist
    redirect "/bands?language=#{params['language']}"
  end
  @title = "Learn #{@language_name} with #{@artist['name']}"
  tracks =  Kantas.top_tracks(params['mbid']).first(40)
  tracks_with_lyrics = []
  tracks.each do |track_title|
    lyrics = Kantas.lyrics(params['mbid'], track_title, params['language'])
    tracks_with_lyrics << lyrics if lyrics
  end
  @tracks = tracks_with_lyrics.uniq {|t| t['track_id']}
  erb :tracks
end

get '/bands/:mbid/tracks/:track_id' do
  unless Kantas.languages.keys.include?(params['language']) && params['mbid']
    redirect '/'
  end

  @language_name = Kantas.languages[params['language']]['name']
  track = Kantas.track_by_id(params['track_id'])

  @lyrics_with_time = nil
  if track['has_subtitles'] == 1
    response, @lyrics_with_time = Kantas.lyrics_with_time_by_track_id(params['track_id'])
  end
  if @lyrics_with_time
    lyrics = @lyrics_with_time.map{|i| i[1]}.join("\n")
  else
    response = Kantas.lyrics_by_track_id(params['track_id'])
    lyrics = response['lyrics_body']
  end
  @track = track.merge(response)
  @lyrics_with_blanks = Kantas.lyrics_with_blanks(lyrics)
  @title = "Learn #{@language_name} with #{@track['artist_name']}"

  erb :track
end

get '/bands/:mbid/tracks/:track_id/game' do
  unless Kantas.languages.keys.include?(params['language']) && params['mbid']
    redirect '/'
  end

  @language_name = Kantas.languages[params['language']]['name']

  @track = Kantas.track_by_id(params['track_id'])
  @words_with_times = {}

  lyrics_with_time = nil
  if @track['has_subtitles'] == 1
    response, lyrics_with_time = Kantas.lyrics_with_time_by_track_id(params['track_id'])

    game_words = Kantas.game_words(lyrics_with_time.map{|i| i[1]}.join("\n"))

    words_and_time = {}
    words_with_all_times = {}
    lyrics_with_time.each_with_index do |line, i|
      time, line = line.first, line.last
      words = line.strip.split(' ').map {|s| Kantas.clean_word(s)}.select {|s| s && s != ''}
      words.each_with_index do |word, j|
        clean_word = Kantas.clean_word(word)
        if game_words.include?(clean_word)
          words_with_all_times[clean_word] ||= []
          words_with_all_times[clean_word] << time
          words_and_time[clean_word] ||= [(time + (j/2.0)), (time + j + 2)]
        end
      end
    end

    words_with_time_arr = words_and_time.sort_by {|s| s.last.first}
    last_time = 0
    @words_with_times = {}
    words_with_time_arr.each do |word, times|
      if (times[0] - last_time) > 10
        @words_with_times[word] = times
        last_time = times[0]
      end
    end

    #puts "Picked words: #{@words_with_times.inspect}"

    @play_game = !!lyrics_with_time
    @track = @track.merge(response)
    @title = "Learn #{@language_name} with #{@track['artist_name']}"
  end

  erb :game
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def escape_url(params)
    params.map { |k,v| "#{CGI.escape k.to_s}=#{CGI.escape v.to_s}" }.join('&amp;')
  end
end


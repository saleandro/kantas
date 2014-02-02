require 'cgi'
require 'sinatra'
require File.dirname(__FILE__) + '/lib/kantas'

get '/' do
  @languages = Kantas.languages
  erb :index
end

get '/bands' do
  unless Kantas.languages.keys.include?(params['language'])
    redirect '/'
  end

  if params['artist_name'].strip != ''
    countries =  Kantas.languages[params['language']]['countries']
    @bands = Kantas.bands_by_name(params['artist_name'], countries)
  else
    countries =  Kantas.languages[params['language']]['countries']
    @bands = []
    countries.each do |country|
      @bands += Kantas.bands_in_country(country, params['genre'], 20)
    end
    @bands = @bands.shuffle.first(20)
  end
  erb :bands
end

get '/bands/:mbid/tracks' do
  unless Kantas.languages.keys.include?(params['language']) && params['mbid']
    redirect '/'
  end

  @language_name = Kantas.languages[params['language']]['name']
  @artist = Kantas.artist(params['mbid'])
  tracks =  Kantas.top_tracks(params['mbid']).first(20)
  tracks_with_lyrics = []
  tracks.each do |track_title|
    lyrics = Kantas.lyrics(params['mbid'], track_title)
    if lyrics && lyrics['lyrics_language'] == params['language']
      #echonest_track_id = Kantas.track_id(@artist['name'], track_title)
      #if echonest_track_id
      #  puts Kantas.track_audio_summary(echonest_track_id)
      #end
      tracks_with_lyrics << lyrics
    end
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

  erb :track
end

get '/bands/:mbid/tracks/:track_id/game' do
  unless Kantas.languages.keys.include?(params['language']) && params['mbid']
    redirect '/'
  end

  @language_name = Kantas.languages[params['language']]['name']

  track = Kantas.track_by_id(params['track_id'])

  lyrics_with_time = nil
  if track['has_subtitles'] == 1
    lyrics_with_time.map{|i| i[1]}.join("\n") if lyrics_with_time
    response, lyrics_with_time = Kantas.lyrics_with_time_by_track_id(params['track_id'])
    lyrics_with_blanks = Kantas.lyrics_with_blanks(lyrics_with_time.map{|i| i[1]}.join("\n"), min_word_length: 3)
    @words_with_times = {}
    picked_words = []

    lyrics_with_blanks['lyrics_body'].each_with_index do |line, i|
      line.each_with_index do |word, j|
        if word == '__BLANK__'
          picked_words << lyrics_with_blanks['removed_words'][i][j].first
        end
      end
    end

    puts lyrics_with_time.inspect
    lyrics_with_blanks['lyrics_body'].each_with_index do |line, i|
      line.each_with_index do |word, j|
        clean_word = lyrics_with_blanks['lyrics_body'][i][j]
        if picked_words.include?(clean_word)
          @words_with_times[clean_word] ||= []
          @words_with_times[clean_word] << [(lyrics_with_time[i][0] + j + 1), (lyrics_with_time[i][0] + j + 1.5)]
        end
      end
    end

    puts @words_with_times.inspect
    @play_game = !!lyrics_with_time

    @track = track.merge(response)
  end

  erb :game
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def escape_url(params)
    params.map { |k,v| "#{CGI.escape k.to_s}=#{CGI.escape v.to_s}" }.join('&amp;')
  end

  def congrats_message(language)
    Kantas.languages[language]['message']
  end
end


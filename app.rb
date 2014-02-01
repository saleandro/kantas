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

  countries =  Kantas.languages[params['language']]['countries']
  bands = []
  countries.each do |country|
    bands << Kantas.bands_in_country(country, params['genre'])
  end
  @bands = bands.flatten.compact.shuffle.first(18)
  erb :bands
end

get '/bands/:mbid/tracks' do
  unless Kantas.languages.keys.include?(params['language']) && params['mbid']
    redirect '/'
  end

  @language_name = Kantas.languages[params['language']]['name']
  @artist = Kantas.artist(params['mbid'])
  tracks =  Kantas.top_tracks(params['mbid'])
  tracks_with_lyrics = []
  tracks.each do |track|
    lyrics = Kantas.lyrics(params['mbid'], track['title'])
    tracks_with_lyrics << lyrics if lyrics && lyrics['lyrics_language'] == params['language']
  end
  @tracks = tracks_with_lyrics
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
    response = Kantas.subtitle_by_track_id(params['track_id'])
    if response
      @lyrics_with_time = response['subtitle_body'].split("\n").map do |l|
        str_time, lyrics = l.split(']')
        str_time.gsub!('[', '')
        time  = Time.strptime(str_time, '%M:%S.%L')
        time = time.min * 60.0 + time.sec
        [time, lyrics]
      end

      lyrics = @lyrics_with_time.map{|i| i[1]}.join("\n")
    end
  end
  unless @lyrics_with_time
    response = Kantas.lyrics_by_track_id(params['track_id'])
    lyrics = response['lyrics_body']
  end
  @track = track.merge(response)
  @lyrics_with_blanks = Kantas.lyrics_with_blanks(lyrics)

  erb :track
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def escape_url(params)
    params.map { |k,v| "#{CGI.escape k.to_s}=#{CGI.escape v.to_s}" }.join('&amp;')
  end
end


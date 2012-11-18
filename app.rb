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

  @band = {'mbid' => params['mbid']}
  @language_name = Kantas.languages[params['language']]['name']
  @artist = Kantas.artist(params['mbid'])
  tracks =  Kantas.top_tracks(params['mbid'])
  tracks_with_lyrics = []
  tracks.each do |track|
    lyrics = Kantas.lyrics(@band['mbid'], track['title'])
    tracks_with_lyrics << lyrics if lyrics && lyrics['lyrics_language'] == params['language']
  end
  @tracks = tracks_with_lyrics
  erb :tracks
end

get '/bands/:mbid/tracks/:track_id' do
  unless Kantas.languages.keys.include?(params['language']) && params['mbid']
    redirect '/'
  end

  @on_load_javascript = 'renderTrack()'

  @language_name = Kantas.languages[params['language']]['name']
  @band = {'mbid' => params['mbid']}
  track = Kantas.track_by_id(params['track_id'])
  lyrics = Kantas.lyrics_by_track_id(params['track_id'])
  @track = track.merge(lyrics)
  @lyrics_with_blanks = Kantas.lyrics_with_blanks(@track['lyrics_body'])
  erb :track
end

# todo: enconding not working: #india http://localhost:3000/bands/f197a8df-ac2b-4e78-9913-4abf13741f12/tracks/13774484?language=pt

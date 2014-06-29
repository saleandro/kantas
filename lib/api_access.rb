require 'rubygems'
require 'yaml'
require 'open-uri'
require 'json'
require 'curb'
require 'active_support'
require File.dirname(__FILE__) + '/data_store'

class NotFound < StandardError; end

module ApiAccess

  def cached_data_from(url, format=:json)
    data = cached_data(url)
    if expired_cache?(data)
      begin
        case format
          when :json
            data = json_from(url)
            stored_data = data.to_json
          else
            stored_data = data = data_from(url)
        end
        if stored_data && stored_data != ''
          DataStore.set(url, stored_data)
        end
      rescue NotFound
        return nil
      end
    else
      if data && data != ''
        if format == :json
          data = parse_json(data)
        end
      else
        data = nil
      end
    end
    data
  end

  def key(api)
    filename = File.dirname(__FILE__) + '/../config/api_keys.yml'
    if File.exists?(filename)
      @config ||= YAML.load_file(filename)
      @config[api]
    else
      ENV['KEY_' + api.upcase]
    end
  end

  private

  APIS = {musicbrainz: 'http://www.musicbrainz.org/ws/2',
          echonest: 'http://developer.echonest.com/api/v4',
          lastfm: 'http://ws.audioscrobbler.com/2.0/',
          musixmatch: 'http://api.musixmatch.com/ws/1.1'
    }
  def build_url(api, path, params)
    query_string = params.map {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
    query_string = '?'+query_string if query_string != ''
    "#{APIS[api]}#{path}#{query_string}"
  end

  def expired_cache?(data)
    data.nil?
  end

  def cached_data(url)
    DataStore.get(url)
  end

  def json_from(url)
    data_str = data_from(url)
    return parse_json(data_str)
  end

  def parse_json(data_str)
    data = JSON.parse(data_str)
    # musixmatch api doesn't return http error status codes :(
    data = nil if data['message'] && data['message']['header'] && data['message']['header']['status_code'].to_i != 200
    data
  end

  def data_from(url)
    data = read_from(url)
    raise NotFound if (data.nil? || data == '')
    data
  end

  def read_from(url)
    start = Time.now
    res = read_from_curb(url)
    puts "#{Time.now - start}s #{url}"
    res
  end

  def read_from_curb(url, compressed=false)
    curb_connection.url = url
    curb_connection.headers.update({"accept-encoding" => "gzip, compressed"}) if compressed
    curb_connection.http_get
    body =  compressed ? ActiveSupport::Gzip.decompress(curb_connection.body_str) : curb_connection.body_str
    process_response(url, curb_connection.response_code, body)
  end

  def curb_connection
    Thread.current[:transport_curb_easy] ||= Curl::Easy.new
  end

  def read_from_open_uri(url)
    begin
      response = open(url).read
    rescue OpenURI::HTTPError => e
      if e.message =~ /^503/
        status = 503
      elsif e.message =~ /^404/
        status = 404
      else
        raise e
      end
    end

    process_response(url, status, response)
  end

  def process_response(url, status, response)
    status = status.to_i
    if status == 200
      @retry = 0
      return response
    elsif status == 404
      return nil
    elsif status == 503
      #sleep 1
      #@retry = 0 unless @retry
      #@retry += 1
      #read_from(url) if @retry < 5
      return nil
    elsif status == 429
      return nil # echonest limit
    elsif status == 402
      return nil # musixmatch limit
    end
    raise "Error in request: status:#{status.inspect} response:#{response.inspect} url:#{url}"
  end
end

class ApiAccessor
  extend ApiAccess
end


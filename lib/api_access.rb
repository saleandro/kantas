require 'rubygems'
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
        DataStore.set(url, stored_data)
      rescue NotFound
        return nil
      end
    else
      if data != ''
        if format==:json
          data = JSON.parse(data)
        end
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

  def expired_cache?(data)
    data.nil?
  end

  def cached_data(url)
    DataStore.get(url)
  end

  def json_from(url)
    data = data_from(url)
    JSON.parse(data)
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

  def read_from_curb(url)
    curb_connection.url = url
    curb_connection.headers.update({"accept-encoding" => "gzip, compressed"})
    curb_connection.http_get
    process_response(url, curb_connection.response_code, ActiveSupport::Gzip.decompress(curb_connection.body_str))
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
    end
    raise "Error in request: status:#{status.inspect} response:#{response.inspect} url:#{url}"
  end
end
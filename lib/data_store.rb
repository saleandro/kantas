require 'redis'

module DataStore
  class << self
    def set(key, value)
      if store.is_a?(Redis)
        store[key] = value if value
      else
        if get(key)
          store[:cache].filter(:key => key).update(:value => value)
        else
          store[:cache].insert(:key => key, :value => value)
        end
      end
    end

    def get(key)
      if store.is_a?(Redis)
        data = store.get(key)
        (!data || data == 'null') ? nil : data
      else
        store[:cache].filter(:key => key).select(:value).single_value
      end
    end

    private

    def store
      if ENV["DATABASE_URL"]
        @sqldb ||= Sequel.connect ENV["DATABASE_URL"]
      else
        uri = URI.parse('redis://localhost:6379')
        @redisdb ||= Redis.new(:host => uri.host, :port => uri.port, :password => uri.password, :user => uri.user, :thread_safe => true)
      end
    end
  end
end
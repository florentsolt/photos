require "redis"
require "hiredis"

if not defined? DB
  Redis::Client::DEFAULTS.merge!({
    :db => Model::Stream.default(:redis)['db'],
    :path => Model::Stream.default(:redis)['sock'],
    :driver => :hiredis
  })

  DB = Redis.current
else
  raise "Redis is already configured"
end

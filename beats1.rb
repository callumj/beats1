require 'bundler/setup'

$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'beats1/shared'
require 'beats1/now_playing'
require 'beats1/tweet'
require 'beats1/actions'
require 'beats1/models'

APP_DB = if (url = ENV["DB_URL"])
  Beats1::Models.init url
else
  nil
end
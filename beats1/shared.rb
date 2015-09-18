require 'twitter'

module Beats1
  module Shared

    def self.production?
      ENV["environment"] == "production"
    end

    def self.twitter_client
      Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
        config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
        config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
        config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
      end
    end

    def self.twitter_followers(args)
      twitter_client.followers(args)
    end

  end
end
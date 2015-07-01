require 'twitter'

module Beats1
  class Tweet

    def self.tweet
      client = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
        config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
        config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
        config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
      end

      np = Beats1::NowPlaying.now_playing
      raise np.inspect unless (artist = np[:artist]) && (title = np[:title])
      tweet = "#{title} - #{artist}"
      raise tweet unless tweet.length >= 10

      last_tweet = client.user_timeline(ENV["TWITTER_USER"]).first
      if last_tweet == nil || last_tweet.text != tweet
        client.update tweet
        return {tweet: tweet, updated: true}
      else
        return {tweet: tweet, updated: false}
      end
    end

  end
end
require 'twitter'
require 'itunes-search-api'

HASHTAGS = "#beats1"

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
      original_tweet = tweet.dup
      raise tweet unless tweet.length >= 10

      tweet_length = tweet.length

      begin
        res = ITunesSearchAPI.search(term: tweet, country: "US", media: "music")
        if res && (first = res[0]) && (url = first["trackViewUrl"]) && (tweet_length + 21) <= 140
          tweet << " #{url}"
          tweet_length += 21
        end
      rescue StandardError => e
        STDERR.puts "ITunesSearch error: #{e}"
      end

      if " #{HASHTAGS}".length + tweet_length <= 140
        tweet << " #{HASHTAGS}"
      end

      last_tweet = client.user_timeline(ENV["TWITTER_USER"]).first
      if last_tweet == nil || !last_tweet.text.include?(original_tweet)
        client.update tweet
        return {tweet: tweet, updated: true}
      else
        return {tweet: tweet, updated: false}
      end
    end

  end
end
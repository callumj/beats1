require 'twitter'
require 'pry'
require 'emoji_data'

module Beats1
  class Engage

    DECENT = /shout\s?out|thanks\s+to|world|listening|tonight|locked|tuned|premiere|check\s+out|love|can\'t\swait|australia|zane/i
    IGNORE_USERS = ["beats1plays", "momdanita", "radio_scrobble", "zanelowe", "stormyplanet", "beats1com"]
    IGNORE_RETWEETS = IGNORE_USERS.map { |s| "RT @#{s}" }

    def client
      Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
        config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
        config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
        config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
      end
    end

    def s_client
      Twitter::Streaming::Client.new do |config|
        config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
        config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
        config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
        config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
      end
    end

    def begin
      topics = ["beats1", "zanelowe"]
      s_client.filter(track: topics.join(",")) do |object|
        if object.is_a?(Twitter::Tweet)
          puts object.text
          if banned?(object)
            puts "\tBeats1.com Skipping!"
            next
          end

          if IGNORE_USERS.include? object.user.screen_name.downcase
            puts "\tSkipping!"
            next
          end

          if object.retweet? && IGNORE_RETWEETS.any? { |a| object.text.start_with?(a) }
            puts "\tRetweet of ignored user"
            next
          end

          create_tweet object

          if decent?(object) || from_me?(object)
            puts "\tFave!"
            begin
              client.favorite! [object]
            rescue StandardError => err
              puts err.inspect
            end
          end
        end
      end
    end

    def create_tweet(object)
      t = CapturedTweet.new username: object.user.screen_name, user_id: object.user.id, tweet_id: object.id, tweet: object.text
      t.save
    end

    def banned?(object)
      object.uris.any? do |uri|
        uri.expanded_url.to_s.match(/beats1\.com/)
      end
    end

    def from_me?(object)
      object.uris.any? do |uri|
        uri.expanded_url.to_s.match(/twitter\.com\/beats1plays/)
      end
    end

    def decent?(tweet)
      text = tweet.text
      return true if text.match(DECENT)
      EmojiData.scan(text).any?
    end

  end
end
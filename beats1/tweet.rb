require 'twitter'
require 'itunes-search-api'
require 'cgi'

HASHTAGS = "#beats1"

module Beats1
  class Tweet

    class Error < StandardError; end
    class NoArtistError < Error; end
    class SmallLengthError < Error; end

    def client
      @client ||= Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
        config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
        config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
        config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
      end
    end

    def followers(args)
      client.followers(args)
    end

    def tweet
      np = Beats1::NowPlaying.now_playing
      unless (artist = np[:artist]) && (title = np[:title])
        @last_known_show = title if title
        raise NoArtistError, np.inspect
      end
      tweet = "#{title} - #{artist}"

      raise SmallLengthError, tweet unless tweet.length >= 10

      lst = last_tweet
      if lst != nil && normalize(lst).include?(normalize(tweet))
        return {tweet: tweet, updated: false}
      end

      tweet_length = tweet.length

      itunes_id = nil
      begin
        res = search_itunes tweet, artist
        if res && (first = res[0]) && (url = first["trackViewUrl"]) && (tweet_length + 21) <= 140
          itunes_id = first["trackId"]
          tweet << " #{url}"
          tweet_length += 21
        end
      rescue StandardError => e
        STDERR.puts "ITunesSearch error: #{e}"
      end

      if " #{HASHTAGS}".length + tweet_length <= 140
        tweet << " #{HASHTAGS}"
      end

      update tweet
      {
        tweet: tweet,
        artist: artist,
        title: title,
        last_known_show: @last_known_show,
        updated: true,
        itunes_id: itunes_id
      }
    end

    def update(tweet)
      #client.update tweet
      @last_tweet = tweet
    end

    def last_tweet
      if @last_tweeted_updated && ((Time.now - @last_tweeted_updated) >= 60)
        STDERR.puts "Refreshing tweet"
        @last_tweet = nil
      end

      @last_tweet ||= begin
        last_tweet = client.user_timeline(ENV["TWITTER_USER"]).first
        return nil unless last_tweet
        @last_tweeted_updated = Time.now
        CGI.unescapeHTML last_tweet.text
      end
    end

    def normalize(txt)
      txt.gsub(/([^A-Za-z0-9_\- ]+)/,"").gsub(/\s+/, " ")
    end

    def search_itunes(tweet, artist)
      res = ITunesSearchAPI.search(term: tweet, country: "US", media: "music")
      return nil unless res
      closest = res.find do |f|
        f["artistName"] == artist
      end
      if closest
        res.unshift closest
      end
      res
    end

  end
end
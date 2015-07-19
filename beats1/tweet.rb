require 'twitter'
require 'itunes-search-api'
require 'cgi'
require 'pry'

HASHTAGS = "#beats1"

module Beats1
  class Tweet

    class Error < StandardError; end
    class NoArtistError < Error; end
    class SmallLengthError < Error; end

    def client
      Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV["TWITTER_CONSUMER_KEY"]
        config.consumer_secret     = ENV["TWITTER_CONSUMER_SECRET"]
        config.access_token        = ENV["TWITTER_ACCESS_TOKEN"]
        config.access_token_secret = ENV["TWITTER_ACCESS_SECRET"]
      end
    end

    def followers(args)
      client.followers(args)
    end

    def refresh_current_program
      p = Beats1::NowPlaying.programs["programs"]
      return unless p
      show = p.detect { |p| Range.new(p["start"]/1000,p["end"]/1000).include?(Time.now.to_i)}
      return unless show
      diff = Time.now.to_i - (show["start"]/1000)
      if @last_known_show != show && (diff <= 60) && !@last_tweet.include?(show["title"])
        begin
          opts = {}
          t = "Now up on @Beats1: #{show["title"]}"
          if show["image"]
            media_id = url_to_media_id artworkUrl
            opts[:media_ids] = media_id if media_id
          end
          update t, opts
        rescue StandardError => err
          STDERR.puts err.inspect
        end
      end
      @last_known_show = show["title"]
    end

    def tweet
      np = Beats1::NowPlaying.now_playing
      unless (artist = np[:artist]) && (title = np[:title])
        raise NoArtistError, np.inspect
      end
      tweet = "#{title} - #{artist}"

      raise SmallLengthError, tweet unless tweet.length >= 10

      lst = last_tweet
      if lst != nil && normalize(lst).include?(normalize(tweet))
        return {tweet: tweet, updated: false}
      end

      tweet_length = tweet.length

      media_id = nil
      itunes_id = nil
      result = nil
      begin
        res = search_itunes title, artist
        if res && res[0]
          result = res[0]
        end
        if result && (url = result["trackViewUrl"]) && (tweet_length + 21) <= 140
          url.gsub!(/\/itunes/, "/geo.itunes")
          itunes_id = result["trackId"]
          tweet << " #{url}"
          tweet_length += 21

          # upload media object of iTunes artwork
          artworkUrl = result["artworkUrl30"].gsub("30x30-50.jpg", "500x500-75.jpg")
          media_id = url_to_media_id artworkUrl
        end
      rescue StandardError => e
        STDERR.puts "ITunesSearch error: #{e} #{e.backtrace}"
      end

      if " #{HASHTAGS}".length + tweet_length <= 140
        tweet << " #{HASHTAGS}"
      end

      opts = {}
      if media_id
        opts = {media_ids: media_id}
      end
      update tweet, opts
      {
        tweet: tweet,
        artist: artist,
        title: title,
        last_known_show: @last_known_show,
        updated: true,
        itunes_id: itunes_id,
        genre: result && result["primaryGenreName"]
      }
    end

    def update(tweet, tw_opts = {})
      STDOUT.puts "Tweet: #{tweet}. Opts: #{tw_opts}"
      begin
        client.update tweet, tw_opts
      rescue StandardError => err
        STDERR.puts err.inspect
        client.update tweet
      end
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

    def search_itunes(title, artist)
      res = ITunesSearchAPI.search(term: "#{title} - #{artist}", country: "US", media: "music")
      return nil unless res
      normed = normalize title
      res.select! do |f|
        ["trackName", "trackCensoredName"].any? do |k|
          next false unless (f[k] && val = normalize(f[k]))
          val[0..5] == normed[0..5]
        end
      end
      closest = res.find do |f|
        f["artistName"] == artist
      end
      if closest
        res.unshift closest
      end
      res
    end

    def url_to_media_id(url)
      resp = Faraday.get url
      if resp.status == 200
        begin
          temp = Tempfile.new(["artwork", ".jpg"])
          temp.write resp.body
          temp.rewind
          return client.upload temp
        rescue StandardError => err
          STDERR.puts err.inspect
          return nil
        ensure
          if temp
            temp.close
            temp.unlink
          end
        end
      end
    end

  end
end
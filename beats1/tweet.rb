require 'twitter'
require 'itunes-search-api'
require 'cgi'
require 'pry'
require 'beats1/tweet_db'
require 'beats1/mb_searcher'
require 'timeout'

HASHTAGS = "#beats1"

module Beats1
  class Tweet

    class Error < StandardError; end
    class NoArtistError < Error; end
    class SmallLengthError < Error; end

    def self.db
      @@db ||= Beats1::TweetDB.new
    end

    def db
      self.class.db
    end

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
      if @last_known_show != show && (diff <= 60) && !db.tweeted?(show["title"])
        begin
          opts = {}
          t = "Now up on @Beats1: #{show["title"]}"

          if show_twitter =(twitter_for_show show["title"])
            t << " @#{show_twitter}"
          end

          if show["image"]
            media_id = url_to_media_id show["image"]
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

      if db.tweeted? tweet
        return {tweet: tweet, updated: false}
      end

      artist_info = Beats1::MBSearcher.search_mb artist
      if artist_info && (tw_artist = artist_info.twitter)
        tweet << " (@#{tw_artist})"
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
      tweet_data = update tweet, opts
      {
        tweet: tweet,
        artist: artist,
        title: title,
        last_known_show: @last_known_show,
        updated: true,
        itunes_id: itunes_id,
        genre: result && result["primaryGenreName"],
        tweet_id: tweet_data && tweet_data.id,
        mb_id: artist_info && artist_info.identifier
      }
    end

    def update(tweet, tw_opts = {})
      raise "Dupe tweet!" if db.tweeted? tweet
      STDOUT.puts "Tweet: #{tweet}. Opts: #{tw_opts}"
      res = nil
      begin
        res = client.update tweet, tw_opts
      rescue StandardError => err
        STDERR.puts err.inspect
        res = client.update tweet
      end
      db.record_tweet tweet
      res
    end

    def refresh_last_tweet
      if @last_tweeted_updated && ((Time.now - @last_tweeted_updated) <= 60)
        return # no update needed
      end

      STDERR.puts "Fetching latest tweet...."
      last_tweet = client.user_timeline(ENV["TWITTER_USER"]).first
      return nil unless last_tweet
      @last_tweeted_updated = Time.now
      escape = CGI.unescapeHTML last_tweet.text
      db.record_tweet(escape) unless db.tweeted?(escape)
    end

    def twitter_for_show(show)
      return unless defined?(::Show) # we have weird lazy load thanks to Sequel
      s = Show.find(name: show)
      return unless s
      s.twitter
    end

    def search_itunes(title, artist)
      original = res = ITunesSearchAPI.search(term: "#{title} - #{artist}", country: "US", media: "music")
      return nil unless res
      normed = normalize title
      res = res.select do |f|
        ["trackName", "trackCensoredName"].any? do |k|
          next false unless (f[k] && val = normalize(f[k]))
          val[0..5] == normed[0..5]
        end
      end
      a = normalize(artist)
      res = res.select do |f|
        next unless f["artistName"]
        norm = normalize(f["artistName"])
        norm == a || norm.include?(a) || a.include?(norm)
      end

      if res.length == 0
        debug_itunes_failure title, artist, original
      end

      res
    end

    def debug_itunes_failure(title, artist, original)
      STDERR.puts "No iTunes tracks found for #{title} - #{artist}"
      unless original.length == 0
        debug = original.map do |t|
          "#{t["trackName"]} - #{t["artistName"]}"
        end
        STDERR.puts "Data: #{debug.join("\r\n")}"
      end
    rescue Error => err
      STDERR.puts "Err: #{err}"
    end

    def normalize(txt)
      txt.gsub(/([^A-Za-z0-9_\- ]+)/,"").gsub(/\s+/, " ")
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
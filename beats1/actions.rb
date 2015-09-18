module Beats1
  module Actions

    def self.tweeter
      @tweeter ||= Beats1::Tweet.new
    end

    def self.update
      begin
        data = tweeter.tweet
        if data[:updated]
          STDOUT.puts data.inspect
          if APP_DB
            PlayedTrack.create title: data[:title], artist: data[:artist], played_at: Time.now,
              last_known_show: data[:last_known_show], itunes_id: data[:itunes_id], genre: data[:genre],
              tweet_id: data[:tweet_id], mb_id: data[:mb_id]
          end
        end
      rescue Beats1::Tweet::Error => e
        STDERR.puts "Error: #{e.inspect}"
      end
    end

    def self.refresh_current_program
      tweeter.refresh_current_program
    end

    def self.refresh_last_tweet
      tweeter.refresh_last_tweet
    end

  end
end
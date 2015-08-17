require 'thread'

module Beats1
  class TweetDB

    MAX_LENGTH = 10

    def initialize
      @tweets = []
      @mutex = Mutex.new
    end

    def tweeted?(text)
      txt = normalize text
      @mutex.synchronize do
        @tweets.any? do |tw|
          tw.include?(txt) || txt.include?(tw)
        end
      end
    end

    def record_tweet(text)
      norm = normalize text
      @mutex.synchronize do
        STDERR.puts "Pushing #{norm}"
        @tweets.push norm
        if @tweets.length >= MAX_LENGTH
          evict = @tweets.shift
            STDERR.puts "Evicting #{evict}"
         end
      end
    end

    def normalize(str)
      return str unless str.is_a?(String)
      str.gsub(/(?:f|ht)tps?:\/[^\s]+/, "").gsub(/#\w+/,"").strip.gsub(/\W+/,"_")
    end

  end
end
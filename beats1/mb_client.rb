require 'musicbrainz'

module Beats1
  class MBClient

    def self.init_once
      return if defined?(@@init_once) && @init_once
      @@init_once = true
      MusicBrainz.configure do |c|
        c.web_service_url = ENV["MUSICBRAINZ_URL"] || "http://nl3.callumj.com:5000/ws/2/"

        # Application identity (required)
        c.app_name = "Local"
        c.app_version = "1.0"
        c.contact = "local@callumj.com"

        # Querying config (optional)
        c.query_interval = 0.2 # seconds
        c.tries_limit = 10
      end
    end

    def self.find_artist(name, track_title = nil)
      init_once

      results = MusicBrainz::Artist.search name
      results.select! do |res|
        res[:type] != nil
      end
      return nil unless (res = results.first)
      a = MusicBrainz::Artist.find res[:id]
      twitter = nil
      if a.urls && (social = a.urls[:social_network])
        twitter_url = social.detect do |soc|
          soc.match(/twitter\.com/)
        end
        if twitter_url
          match = twitter_url.match(/https?\:\/\/(?:www\.)?twitter\.com\/([^\/]+)/)
          twitter = match && match[1]
        end
      end
      {artist: a, twitter: twitter}
    end

  end
end
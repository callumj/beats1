require 'beats1/mb_client'

module Beats1
  module MBSearcher

    class SearchResult
      attr_accessor :identifier
      attr_accessor :twitter
    end

    def self.search_mb(artist)
      result = begin
        Timeout::timeout(5) do
          Beats1::MBClient.find_artist artist
        end
      rescue
        nil
      end

      ret = nil
      if result
        ret = SearchResult.new.tap do |s|
          s.identifier = result[:artist].id
          s.twitter = result[:twitter]
        end
      end

      return ret if ret && ret.twitter

      # we are fine with no model being available (db not loaded)
      return nil unless defined?(::Artist)

      # fall back to this gap fill model
      base = Artist.where("name = ?", artist)
      if ret
        base = base.or("mb_id = ?", ret.identifier)
      end
      if a = base.first
        return SearchResult.new.tap do |s|
          s.identifier = "internal:#{a.id}"
          s.twitter = a.twitter
        end
      end

      nil
    end

  end
end
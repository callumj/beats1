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

      if result
        return SearchResult.new.tap do |s|
          s.identifier = result[:artist].id
          s.twitter = result[:twitter]
        end
      end
      nil
    end

  end
end
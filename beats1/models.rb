require 'sequel'

module Beats1
  module Models

    def self.init(url)
      database = Sequel.connect(url)
      create database
      require 'beats1/artist'
      require 'beats1/played_track'
      require 'beats1/show'
      require 'beats1/captured_tweet'
      return database
    end

    def self.create(db)
      db.create_table? :played_tracks do |t|
        primary_key :id
        String  :title
        String  :artist
        Time    :played_at
        String  :last_known_show
        Bignum  :itunes_id
        String  :genre
        Bignum  :tweet_id
        String  :mb_id
      end

      db.create_table? :artists do |t|
        primary_key :id
        String  :name
        String  :mb_id
        String  :twitter

        index [:mb_id]
        index [:name]
      end

      db.create_table? :shows do |t|
        primary_key :id
        String  :name
        String  :twitter

        index [:name]
      end

      db.create_table? :captured_tweets do |t|
        primary_key :id
        String  :username
        Bignum  :user_id
        Bignum  :tweet_id
        String  :tweet, text: true
        Time    :recorded_at
        Bignum  :played_track_id
      end
    end

  end
end
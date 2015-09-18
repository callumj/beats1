require 'sequel'

class CapturedTweet < Sequel::Model
  def before_create
    self.played_track_id ||= PlayedTrack.max(:id)
    self.recorded_at ||= Time.now
    super
  end
end
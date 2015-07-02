require 'csv'
require 'faraday'
require 'tempfile'

module Beats1
  class NowPlaying

    def self.now_playing
      conn = Faraday.new(url: 'http://itsliveradiobackup.apple.com/') do |faraday|
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end

      # fetch the available M3Us
      resp = conn.get("/streams/hub02/session02/64k/prog.m3u8")
      raise "No body" unless (m3u = resp.body) != nil && m3u.length > 0
      aac_file = m3u.split.select { |l| l.match(/\.aac/) }.sort.last
      raise "No file" unless aac_file

      # fetch the latest M3U file
      resp = conn.get("/streams/hub02/session02/64k/#{aac_file}")
      raise "No AAC body" unless (aac = resp.body) != nil && aac.length > 0
      file = Tempfile.new(aac_file)
      file.write resp.body
      file.close

      # decode in ffmpeg
      metadata_file = Tempfile.new "metadata"
      res = system `/bin/bash -c 'ffmpeg -y -i #{file.path} -f ffmetadata #{metadata_file.path} &> /dev/null'`
      metadata_file.seek 0
      contents = metadata_file.read
      raise "No metadata body" unless contents.length > 0
      listing = contents.split(/\n/) rescue (raise contents)
      hsh = {}
      listing.each do |l|
        key = l.match(/^(?:(title|artist|album)=)/)
        next unless key
        val = l.gsub(key[0], "")
        hsh[key[1].to_sym] = val
      end
      hsh
    ensure
      if file
        file.unlink
      end

      if metadata_file
        metadata_file.close
        metadata_file.unlink
      end
    end

  end
end
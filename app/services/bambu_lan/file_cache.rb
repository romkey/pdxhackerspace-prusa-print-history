require 'digest'
require 'fileutils'
require 'json'

module BambuLan
  # Disk cache for parsed .3mf metadata and the extracted plate thumbnail.
  # Avoids downloading the same project on every one-minute poll.
  class FileCache
    ROOT = Rails.root.join('tmp/bambu_cache')
    PREVIEW = Rails.root.join('tmp/bambu_previews')
    TOKEN = /\Abambu-preview:([a-f0-9]{64})\.png\z/
    MISS = :miss

    def self.fetch(key, expires_in:, missing_expires_in: 10.minutes)
      cached = read(cache_id(key))
      return cached unless cached == MISS

      value = yield
      write(cache_id(key), value, expires_in: value.nil? ? missing_expires_in : expires_in)
      value
    end

    def self.store_preview(bytes)
      return nil if bytes.blank?

      id = Digest::SHA256.hexdigest(bytes)
      FileUtils.mkdir_p(PREVIEW)
      File.binwrite(PREVIEW.join("#{id}.png"), bytes)
      "bambu-preview:#{id}.png"
    end

    def self.read_preview(token)
      match = TOKEN.match(token.to_s)
      return nil unless match

      path = PREVIEW.join("#{match[1]}.png")
      File.binread(path) if File.file?(path)
    end

    def self.cache_id(key)
      Digest::SHA256.hexdigest(key.to_s)
    end

    def self.read(id)
      path = ROOT.join(id)
      return MISS unless File.file?(path)

      payload = JSON.parse(File.read(path))
      return MISS if payload['expires_at'].to_i < Time.current.to_i

      payload['value']
    rescue JSON::ParserError
      MISS
    end

    def self.write(id, value, expires_in:)
      FileUtils.mkdir_p(ROOT)
      payload = { 'expires_at' => (Time.current + expires_in).to_i, 'value' => value }
      temp = ROOT.join("#{id}.#{Process.pid}.tmp")
      File.write(temp, JSON.generate(payload))
      File.rename(temp, ROOT.join(id))
    end
  end
end

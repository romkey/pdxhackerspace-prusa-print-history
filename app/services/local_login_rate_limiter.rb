class LocalLoginRateLimiter
  LIMIT = 5
  PERIOD = 15.minutes

  class << self
    def throttled?(ip)
      return false if ip.blank?

      attempts(ip) >= LIMIT
    end

    def record_failure(ip)
      return if ip.blank?

      key = cache_key(ip)
      count = store.read(key).to_i + 1
      store.write(key, count, expires_in: PERIOD)
    end

    def reset!(ip)
      store.delete(cache_key(ip)) if ip.present?
    end

    private

    def attempts(ip)
      store.read(cache_key(ip)).to_i
    end

    def cache_key(ip)
      "local_login_attempts:#{ip}"
    end

    def store
      return Rails.cache unless Rails.cache.is_a?(ActiveSupport::Cache::NullStore)

      @store ||= ActiveSupport::Cache::MemoryStore.new
    end
  end
end

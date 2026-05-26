timezone = ENV.fetch('TIMEZONE', 'UTC')
Time.zone = timezone
ENV['TZ'] = timezone

Rails.logger.info "Timezone configured: #{Time.zone.name} (#{Time.zone.now})"

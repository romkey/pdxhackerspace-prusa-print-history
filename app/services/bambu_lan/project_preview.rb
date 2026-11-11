module BambuLan
  # The plate image lives inside the sliced project. A running print usually
  # reports the extracted gcode path, so the project is also looked up by the
  # task name on the printer's FTPS storage.
  class ProjectPreview
    def initialize(printer, print, ftps, cache_key:)
      @printer = printer
      @print = print.is_a?(Hash) ? print : {}
      @ftps = ftps
      @cache_key = cache_key
    end

    def details
      FileCache.fetch(@cache_key, expires_in: 6.hours) { fetch_details }
    end

    private

    def fetch_details
      errors = []
      candidates.each do |path|
        archive = download(path, errors)
        return stored(path, archive) if archive
      end
      log_miss(errors)
      nil
    end

    def download(path, errors)
      archive = Archive.parse(@ftps.download(path))
      return archive if archive

      errors << [path, 'not a sliced project']
      nil
    rescue Error => e
      errors << [path, e.message]
      nil
    end

    def stored(path, archive)
      token = FileCache.store_preview(archive.png)
      state = token ? 'saved' : 'missing'
      Rails.logger.info("Photo preview #{@printer.name}: #{path} (plate image #{state})")
      payload(archive, token)
    end

    def payload(archive, token)
      details = {}
      details['grams'] = archive.grams unless archive.grams.nil?
      details['token'] = token if token
      details.presence
    end

    def log_miss(errors)
      Rails.logger.info("Photo preview #{@printer.name}: #{miss_message(errors)}")
    end

    def miss_message(errors)
      message = "no project file (gcode_file=#{reported_file.presence || 'none'}, " \
                "subtask=#{task_name.presence || 'none'})"
      tried = errors.map { |path, reason| "#{path} (#{reason})" }.join('; ')
      message = "#{message}. Tried #{tried}" if tried.present?
      return message unless internal_plate? && errors.any?

      "#{message}. That gcode path is inside the printer and is not a file FTPS can download."
    end

    def candidates
      (reported_candidates + task_candidates).flat_map { |path| locations(path) }.uniq
    end

    def reported_candidates
      path = reported_file
      return [] unless project?(path)

      [path]
    end

    def task_candidates
      name = task_name
      return [] if name.blank?
      return [name] if project?(name)

      ["#{name}.gcode.3mf", "#{name}.3mf"]
    end

    def locations(path)
      bare = path.sub(%r{\A/+}, '')
      return [bare] if bare.include?('/')

      [bare, "cache/#{bare}", "model/#{bare}"]
    end

    def reported_file
      raw = @print['gcode_file'].presence || @print['file']
      raw.to_s.strip.sub(%r{\Aftp://}i, '').sub(%r{\A/+}, '').presence
    end

    def task_name
      name = @print['subtask_name'].to_s.strip
      return nil if name.blank? || name.match?(%r{[/\\]}) || name.include?('..')

      name
    end

    def project?(path)
      path.to_s.downcase.end_with?('.3mf')
    end

    def internal_plate?
      reported_file.to_s.match?(/plate_\d+\.gcode\z/i)
    end
  end
end

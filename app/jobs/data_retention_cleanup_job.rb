class DataRetentionCleanupJob < ApplicationJob
  queue_as :default

  def perform
    DataRetentionCleaner.new.run!
  end
end

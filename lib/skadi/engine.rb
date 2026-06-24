module Skadi
  class Engine < ::Rails::Engine
    isolate_namespace Skadi

    config.after_initialize do
      # Validate the configuration and output any errors to the Rails log
      Skadi.configuration.validate!

      validate_cache_store!

      if Skadi.configuration.db_connects_to
        Skadi::ApplicationRecord.connects_to(**Skadi.configuration.db_connects_to)
      end

      if Skadi.configuration.user_model
        Skadi::Visit.belongs_to :user, class_name: Skadi.configuration.user_model.to_s, optional: true
      end
    end

    def self.validate_cache_store!
      # Only the anonymity sets uses the cache
      return unless Skadi.configuration.use_anonymity_sets

      # A different cache store is common for development and testing
      return if Rails.env.local?

      if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
        Rails.logger.warn("Skadi: anonymity sets are enabled but Rails.cache is a ActiveSupport::Cache::NullStore. The pepper won't be saved so anonymity sets have been disabled.")

        Skadi.configuration.use_anonymity_sets = false
      end

      if Rails.cache.is_a?(ActiveSupport::Cache::MemoryStore)
        Rails.logger.warn("Skadi: anonymity sets are enabled but Rails.cache is a ActiveSupport::Cache::MemoryStore. If Rails is running across multiple processes or servers, the pepper won't be shared across processes, breaking anonymity-set grouping. Use a shared store (SolidCache/Redis/Memcached).")
      end
    end
  end
end

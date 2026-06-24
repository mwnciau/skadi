require_relative "test_case"

module Skadi::Unit
  class EngineTest < TestCase
    setup do
      Rails.env = "production"
      @existing_cache = Rails.cache

      Skadi.configuration.use_anonymity_sets = true
    end

    teardown do
      Rails.env = "test"
      Rails.cache = @existing_cache
    end

    test "warns and disabled anonymity sets when using null cache" do
      Rails.cache = ActiveSupport::Cache::NullStore.new
      Rails.logger.expects(:warn).with("Skadi: anonymity sets are enabled but Rails.cache is a ActiveSupport::Cache::NullStore. The pepper won't be saved so anonymity sets have been disabled.")

      Skadi::Engine.validate_cache_store!
      assert_equal false, Skadi.configuration.use_anonymity_sets
    end

    test "warns when using memory cache" do
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      Rails.logger.expects(:warn).with("Skadi: anonymity sets are enabled but Rails.cache is a ActiveSupport::Cache::MemoryStore. If Rails is running across multiple processes or servers, the pepper won't be shared across processes, breaking anonymity-set grouping. Use a shared store (SolidCache/Redis/Memcached).")

      Skadi::Engine.validate_cache_store!
      # But does not disable anonymity sets
      assert_equal true, Skadi.configuration.use_anonymity_sets
    end

    test "does not validate cache in development" do
      Rails.env = "development"
      Rails.cache = ActiveSupport::Cache::NullStore.new
      Rails.logger.expects(:warn).times(0)

      Skadi::Engine.validate_cache_store!
      assert_equal true, Skadi.configuration.use_anonymity_sets
    end

    test "does not validate cache in test" do
      Rails.env = "development"
      Rails.cache = ActiveSupport::Cache::NullStore.new
      Rails.logger.expects(:warn).times(0)

      Skadi::Engine.validate_cache_store!
      assert_equal true, Skadi.configuration.use_anonymity_sets
    end

    test "does not validate cache when anonymity sets are disabled" do
      Skadi.configuration.use_anonymity_sets = false
      Rails.cache = ActiveSupport::Cache::NullStore.new
      Rails.logger.expects(:warn).times(0)

      Skadi::Engine.validate_cache_store!
    end
  end
end

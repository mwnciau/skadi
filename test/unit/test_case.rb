require "test_helper"

module Skadi
  module Unit
    class TestCase < ActiveSupport::TestCase
      # Disable loading fixtures
      def setup_fixtures = nil
      def teardown_transactional_fixtures = nil

      setup do
        # Reset the configuration
        Skadi.configuration = Skadi::Configuration.new

        Rails.cache.clear
      end
    end
  end
end

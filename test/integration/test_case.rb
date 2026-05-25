require "test_helper"

module Skadi
  module Integration
    class TestCase < ::ActionDispatch::IntegrationTest
      setup do
        # Reset the configuration
        Skadi.configuration = Skadi::Configuration.new
      end
    end
  end
end

require "test_helper"
require "factory_bot_rails"

module Skadi
  module Unit
    class TestCase < ActiveSupport::TestCase
      include ::FactoryBot::Syntax::Methods

      TRACKING_TOKEN = "8cec5a7a-7bf7-403f-b15e-b2e45944182c"

      setup do
        # Reset the configuration
        Skadi.configuration = Skadi::Configuration.new

        Rails.cache.clear
      end
    end
  end
end

require "test_helper"
require "factory_bot_rails"

module Skadi
  module Models
    class TestCase < ActiveSupport::TestCase
      include ::FactoryBot::Syntax::Methods

      setup do
        # Reset the configuration
        Skadi.configuration = Skadi::Configuration.new

        Rails.cache.clear
      end
    end
  end
end

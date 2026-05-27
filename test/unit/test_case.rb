require "test_helper"

module Skadi
  module Unit
    class TestCase < ActiveSupport::TestCase
      setup do
        # Reset the configuration
        Skadi.configuration = Skadi::Configuration.new

        Rails.cache.clear
      end
    end
  end
end

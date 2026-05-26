require "test_helper"

module Skadi
  module Integration
    class TestCase < ::ActionDispatch::IntegrationTest
      setup do
        # Reset the configuration
        Skadi.configuration = Skadi::Configuration.new
      end

      # Helper method for performing GET requests with specified IP, User Agent, etc.
      def get_tracked_action(ip: "127.0.0.1", user_agent: "Test User Agent", referrer: nil)
        headers = {}
        headers["HTTP_USER_AGENT"] = user_agent if user_agent
        headers["REMOTE_ADDR"] = ip if ip
        headers["REFERER"] = referrer if referrer

        get tracked_action_path, headers: headers
      end
    end
  end
end

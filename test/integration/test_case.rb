require "test_helper"
require "factory_bot_rails"

module Skadi
  module Integration
    class TestCase < ::ActionDispatch::IntegrationTest
      include FactoryBot::Syntax::Methods

      TRACKING_TOKEN = "8cec5a7a-7bf7-403f-b15e-b2e45944182c"
      UUID_REGEX = Skadi::CookieManager::UUID_REGEX

      setup do
        # Reset the configuration
        Skadi.configuration = Skadi::Configuration.new

        # Ensure the application state is reset
        ::ApplicationController.current_user = nil
        ::ApplicationController.skadi_dashboard_view = true
        ::ApplicationController.skadi_dashboard_edit = true
        ::ApplicationController.skadi_dashboard_use_sql = true

        Rails.cache.clear
      end

      # Helper method for performing GET requests with specified IP, User Agent, etc.
      def get_tracked_action(ip: "127.0.0.1", user_agent: "Test User Agent", referrer: nil, tracking_token: nil, **params)
        headers = {}
        headers["HTTP_USER_AGENT"] = user_agent if user_agent
        headers["REMOTE_ADDR"] = ip if ip
        headers["REFERER"] = referrer if referrer
        headers["Cookie"] = "skadi_id=#{tracking_token}" unless tracking_token.nil?

        get tracked_action_path, headers: headers, params: params
      end

      def log_in_as(user)
        # Ensure user config is setup
        Skadi.configuration.user_model = "DummyUser"
        Skadi.configuration.user_controller_method = :current_user

        ::ApplicationController.current_user = user
      end

      def assert_see(pattern) = assert _see_in_response?(pattern), "Expected to see \"#{pattern}\" in:\n#{@response.body.inspect}"

      def refute_see(pattern) = refute _see_in_response?(pattern), "Expected not to see \"#{pattern}\" in:\n#{@response.body.inspect}"

      private def _see_in_response?(pattern)
        regex = pattern.is_a?(String) ? Regexp.escape(pattern) : pattern
        return @response.body.to_s.match?(regex)
      end
    end
  end
end

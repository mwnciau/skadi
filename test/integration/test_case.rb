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

        # Ensure the current user is reset
        ::ApplicationController.current_user = nil

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
        Skadi.configuration.user_method = :current_user

        ::ApplicationController.current_user = user
      end
    end
  end
end

require "integration/test_case"

module Skadi::Integration
  module Analytics
    class QueryParametersTest < TestCase
      test "view query parameters are filtered" do
        get tracked_action_path, params: {not_whitelisted: "value"}

        view = Skadi::View.first!
        assert_equal({}, view.query_params)
      end

      test "whitelisted view query parameters are saved" do
        Skadi.configuration.query_param_whitelist = [:whitelisted]

        get tracked_action_path, params: {whitelisted: "value", not_whitelisted: "other_value"}

        view = Skadi::View.first!
        assert_equal({"whitelisted" => "value"}, view.query_params)
      end

      test "view query parameter whitelist symbol or string keys" do
        Skadi.configuration.query_param_whitelist = [:whitelisted_symbol, :whitelisted_string]

        get tracked_action_path, params: {:whitelisted_symbol => "symbol", "whitelisted_string" => "string"}

        view = Skadi::View.first!
        assert_equal({"whitelisted_symbol" => "symbol", "whitelisted_string" => "string"}, view.query_params)
      end

      test "view query parameter whitelist is disabled by config" do
        Skadi.configuration.use_query_param_whitelist = false
        Skadi.configuration.query_param_whitelist = [:whitelisted]

        get tracked_action_path, params: {whitelisted: "value", not_whitelisted: "other_value"}

        view = Skadi::View.first!
        assert_equal({"whitelisted" => "value", "not_whitelisted" => "other_value"}, view.query_params)
      end

      test "post query parameters are saved as view query parameters" do
        Skadi.configuration.query_param_whitelist = [:whitelisted]

        post "#{tracked_action_path}?whitelisted=value"

        view = Skadi::View.first!
        assert_equal({"whitelisted" => "value"}, view.query_params)
      end

      test "post parameters are not saved as view query parameters" do
        Skadi.configuration.use_query_param_whitelist = false
        Skadi.configuration.query_param_whitelist = [:whitelisted]

        post tracked_action_path, params: {whitelisted: "value"}

        view = Skadi::View.first!
        assert_equal({}, view.query_params)
      end

      test "referrer query parameters are whitelisted" do
        Skadi.configuration.query_param_whitelist = [:whitelisted]

        get_tracked_action(referrer: "https://example.com/?whitelisted=value&not_whitelisted=other_value")

        visit = Skadi::Visit.first!
        assert_equal "example.com/?whitelisted=value", visit.referrer

        view = Skadi::View.first!
        assert_equal "example.com/?whitelisted=value", view.referrer
      end

      test "landing page query parameters are not stored" do
        cookies[:skadi_id] = TRACKING_TOKEN
        Skadi.configuration.query_param_whitelist = [:whitelisted]
        get tracked_action_path, params: {whitelisted: "value"}

        visit = Skadi::Visit.first!
        assert_equal "/track", visit.landing_page
      end
    end
  end
end

require "integration/test_case"

module Skadi::Integration
  module Analytics
    class OptOutTest < TestCase
      TEST_IP = "127.0.0.1"
      TEST_USER_AGENT = "Test User Agent"
      DEFAULT_HEADERS = {"HTTP_USER_AGENT" => TEST_USER_AGENT, "REMOTE_ADDR" => TEST_IP, "REFERER" => "https://example.com"}

      test "anonymisation set is disabled by opt out track cookie" do
        cookies["skadi_tracking_opt_out"] = "1"

        get_tracked_action(referrer: "https://example.com/")

        assert_equal 1, Skadi::Visit.count
        assert_equal 1, Skadi::View.count

        visit = Skadi::Visit.first
        assert_nil visit.tracking_token
      end

      test "tracking cookie is ignored with opt out cookie" do
        cookies["skadi_tracking_opt_out"] = "1"
        cookies["skadi_id"] = "00000000-0000-0000-0000-000000000000"

        get_tracked_action(referrer: "https://example.com/")

        visit = Skadi::Visit.first!
        assert_nil visit.tracking_token
      end

      test "current user is ignored with opt out cookie" do
        cookies["skadi_tracking_opt_out"] = "1"
        ApplicationController.current_user = create :user

        get_tracked_action(referrer: "https://example.com/")

        visit = Skadi::Visit.first!
        assert_nil visit.user
      end
    end
  end
end

require "integration/test_case"

module Skadi::Integration
  module Analytics
    class VisitTrackingTest < TestCase
      test "referrer is tracked" do
        get_tracked_action referrer: "https://example.com/referrer"

        visit = Skadi::Visit.first!
        assert_equal "https://example.com/referrer", visit.referrer
      end

      test "bad referrer is not tracked" do
        get_tracked_action referrer: "this is not a valid url"

        visit = Skadi::Visit.first!
        assert_nil visit.referrer
      end

      test "landing page is tracked" do
        get tracked_action_path, headers: {"HTTP_REFERER" => "https://example.com/referrer"}

        visit = Skadi::Visit.first!
        assert_equal "/track", visit.landing_page
      end

      test "utm parameters are tracked" do
        get tracked_action_path, params: {utm_source: "source", utm_medium: "medium", utm_term: "term", utm_content: "content", utm_campaign: "campaign"}

        visit = Skadi::Visit.first!
        assert_equal "source", visit.utm_source
        assert_equal "medium", visit.utm_medium
        assert_equal "term", visit.utm_term
        assert_equal "content", visit.utm_content
        assert_equal "campaign", visit.utm_campaign
      end

      test "visit is not tracked with no useful data" do
        cookies["skadi_tracking_opt_out"] = "1"

        get_tracked_action

        assert_equal 0, Skadi::Visit.count
      end

      test "visit is tracked once within visit_duration" do
        get_tracked_action(tracking_token: TRACKING_TOKEN)

        travel 119.minutes do
          get_tracked_action(tracking_token: TRACKING_TOKEN)
        end

        assert_equal 1, Skadi::Visit.count
      end

      test "visit is tracked twice after visit_duration" do
        get_tracked_action(tracking_token: TRACKING_TOKEN)

        travel 121.minutes do
          get_tracked_action(tracking_token: TRACKING_TOKEN)
        end

        assert_equal 2, Skadi::Visit.count
      end

      test "visit_duration config option works" do
        Skadi.configuration.visit_duration = 4.hours

        get_tracked_action(tracking_token: TRACKING_TOKEN)

        travel 239.minutes do
          get_tracked_action(tracking_token: TRACKING_TOKEN)
        end

        assert_equal 1, Skadi::Visit.count
      end

      test "visit tracks user with consent" do
        Skadi.configuration.user_model = "DummyUser"
        Skadi.configuration.user_method = :current_user

        user = create :user
        ::ApplicationController.current_user = user
        create :visit, user: user

        cookies[:skadi_id] = TRACKING_TOKEN

        get tracked_action_path

        assert_equal 1, Skadi::Visit.count
        visit = Skadi::Visit.first!
        assert_equal user, visit.user
      end

      test "visit does not track user without consent" do
        Skadi.configuration.user_model = "DummyUser"
        Skadi.configuration.user_method = :current_user

        user = create :user
        ::ApplicationController.current_user = user
        create :visit, user: user

        get_tracked_action(referrer: "https://example.com")

        assert_equal 2, Skadi::Visit.count
        visit = Skadi::Visit.last
        assert_nil visit.user
      end

      test "existing visit user is updated" do
        Skadi.configuration.user_model = "DummyUser"
        Skadi.configuration.user_method = :current_user

        user = create :user
        ::ApplicationController.current_user = user
        visit = create :visit, tracking_token: TRACKING_TOKEN, user: nil

        cookies["skadi_id"] = visit.tracking_token

        get tracked_action_path

        assert_equal 1, Skadi::Visit.count
        assert_equal user, visit.reload.user
      end

      private def assert_visit_is_tracked?(**params)
        get_tracked_action(**params)

        assert_equal 1, Skadi::Visit.count
      end

      test("visit is tracked with utm_source") { assert_visit_is_tracked?(utm_source: "source") }
      test("visit is tracked with utm_medium") { assert_visit_is_tracked?(utm_medium: "medium") }
      test("visit is tracked with utm_term") { assert_visit_is_tracked?(utm_term: "term") }
      test("visit is tracked with utm_content") { assert_visit_is_tracked?(utm_content: "content") }
      test("visit is tracked with utm_campaign") { assert_visit_is_tracked?(utm_campaign: "campaign") }
      test("visit is tracked with referrer") { assert_visit_is_tracked?(referrer: "https://example.com/referrer") }
    end
  end
end

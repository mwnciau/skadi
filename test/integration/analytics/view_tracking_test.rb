require "integration/test_case"

module Skadi::Integration
  module Analytics
    class ViewTrackingTest < TestCase
      test "referrer is tracked" do
        get_tracked_action referrer: "https://example.com/referrer"

        view = Skadi::View.first!
        assert_equal "https://example.com/referrer", view.referrer
      end

      test "bad referrer is not tracked" do
        get_tracked_action referrer: "this is not a valid url"

        view = Skadi::View.first!
        assert_nil view.referrer
      end

      test "controller and action is tracked" do
        get_tracked_action(tracking_token: TRACKING_TOKEN)

        assert_equal 1, Skadi::Visit.count
        assert_equal 1, Skadi::View.count

        view = Skadi::View.first!
        assert_equal "tracked", view.controller
        assert_equal "tracked_action", view.action
      end

      test("GET request is tracked") { assert_verb_is_tracked(:get) }
      test("POST request is tracked") { assert_verb_is_tracked(:post) }
      test("PUT request is tracked") { assert_verb_is_tracked(:put) }
      test("PATCH request is tracked") { assert_verb_is_tracked(:patch) }
      test("DELETE request is tracked") { assert_verb_is_tracked(:delete) }

      private def assert_verb_is_tracked(verb)
        cookies[:skadi_id] = TRACKING_TOKEN

        process verb, tracked_action_path

        assert_equal 1, Skadi::Visit.count
        assert_equal 1, Skadi::View.count

        view = Skadi::View.first!
        assert_equal verb.to_s.upcase, view.verb
        assert_equal tracked_action_path, view.path
      end

      test "view is linked to visit" do
        get_tracked_action(tracking_token: TRACKING_TOKEN)

        view = Skadi::View.first!
        assert view.visit.present?
      end

      test "view is tracked when visit is not" do
        cookies["skadi_tracking_opt_out"] = "1"

        get_tracked_action

        assert_equal 0, Skadi::Visit.count
        assert_equal 1, Skadi::View.count
      end
    end
  end
end

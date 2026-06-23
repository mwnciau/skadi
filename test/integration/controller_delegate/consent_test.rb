require "integration/test_case"

module Skadi::Integration
  module ControllerDelegate
    class ConsentTest < TestCase
      UUID_REGEX = Skadi::CookieManager::UUID_REGEX

      setup do
        Skadi.configuration.use_anonymity_sets = true
      end

      test "consent sets tracking cookie" do
        post consent_path

        assert_response :ok
        visit = Skadi::Visit.first!
        assert_equal visit.tracking_token, response.cookies["skadi_id"]
      end

      test "consent sets tracking cookie without visit" do
        cookies["skadi_tracking_opt_out"] = "1"

        post consent_path

        assert_response :ok
        assert_equal 0, Skadi::Visit.count
        assert_match UUID_REGEX, response.cookies["skadi_id"]
      end

      test "consent clears opt out cookie" do
        cookies["skadi_tracking_opt_out"] = "1"

        post consent_path

        assert_response :ok
        assert response.cookies.has_key?("skadi_tracking_opt_out")
        assert_nil response.cookies["skadi_tracking_opt_out"]
      end

      test "opt out sets opt out cookie" do
        post opt_out_path

        assert_response :ok
        assert_equal "1", response.cookies["skadi_tracking_opt_out"]
      end

      test "opt out deletes tracking tokens in existing visits" do
        visit = create :visit, tracking_token: TRACKING_TOKEN

        # Simulate a second visit with the same tracking token
        old_visit = create :visit, tracking_token: TRACKING_TOKEN

        cookies["skadi_id"] = TRACKING_TOKEN

        post opt_out_path

        assert_response :ok
        assert_nil visit.reload.tracking_token
        assert_nil old_visit.reload.tracking_token
      end

      test "opt out deletes user in existing visits" do
        user = create :user
        ApplicationController.current_user = user

        visit = create :visit, user: user, tracking_token: TRACKING_TOKEN

        # Simulate a second visit with the same tracking user
        old_visit = create :visit, user: user

        cookies["skadi_id"] = TRACKING_TOKEN

        post opt_out_path

        assert_response :ok
        assert_nil visit.reload.user
        assert_nil old_visit.reload.user
      end

      test "opt out clears tracking cookie" do
        view = create :view

        cookies["skadi_id"] = TRACKING_TOKEN

        post opt_out_path

        assert_response :ok
        assert response.cookies.has_key?("skadi_id")
        assert_nil response.cookies["skadi_id"]
      end
    end
  end
end

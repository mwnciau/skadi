require "integration/test_case"

module Skadi::Integration
  module ControllerDelegate
    # Tests that the tracking controller correctly handles consent changes, closely mimicking the `Skadi::Integration::TrackingController::ConsentTest` tests; more thorough testing is done in unit tests for the ControllerDelegate class
    class ConsentTest < TestCase
      test "cookie consent" do
        Skadi.configuration.use_anonymity_sets = true

        cookies["skadi_anonymity_set"] = "1"

        get tracked_action_path
        visit = Skadi::Visit.first!
        anonymity_set = visit.tracking_token

        post cookies_on_path

        assert_response :no_content
        assert_equal 1, Skadi::Visit.count

        # Check a new token is generated
        refute_equal anonymity_set, response.cookies["skadi_id"]
        assert_match UUID_REGEX, response.cookies["skadi_id"]

        # Cookies enabled on visits
        assert visit.reload.cookies_enabled

        # Tracking cookie is set
        assert_equal response.cookies["skadi_id"], visit.reload.tracking_token
      end

      test "cookie opt out" do
        visit = create :visit, tracking_token: TRACKING_TOKEN, cookies_enabled: true

        cookies["skadi_id"] = TRACKING_TOKEN

        post cookies_off_path

        assert_response :no_content
        assert_equal 1, Skadi::Visit.count

        # Cookies disabled on visits
        refute visit.reload.cookies_enabled

        # Tracking cookie is deleted
        assert response.cookies.has_key?("skadi_id")
        assert_nil response.cookies["skadi_id"]
      end

      test "anonymity set consent" do
        cookies["skadi_tracking_opt_out"] = "0"

        post anonymity_sets_on_path

        assert_response :no_content

        #  Sets cookie
        assert_equal "1", response.cookies["skadi_anonymity_set"]

        visit = Skadi::Visit.first!

        # Sets tracking token on visit
        assert_match UUID_REGEX, visit.tracking_token

        # Check future visits use the same visit
        get tracked_action_path
        assert_equal 1, Skadi::Visit.count
      end

      test "anonymity set opt out" do
        # Create a visit with an anonymity set
        cookies["skadi_anonymity_set"] = "1"
        get tracked_action_path

        visit = Skadi::Visit.first!
        anonymity_set = visit.tracking_token

        # Simulate a second visit with the same anonymity set
        old_visit = create :visit, tracking_token: anonymity_set

        post anonymity_sets_off_path

        assert_response :no_content

        # Sets cookie
        assert_equal "0", response.cookies["skadi_anonymity_set"]

        # Ensure all visits using the anonymity set are removed
        refute_equal anonymity_set, visit.reload.tracking_token
        refute_equal anonymity_set, old_visit.reload.tracking_token
      end

      test "user consent" do
        user = create :user

        visit = create :visit, tracking_token: TRACKING_TOKEN

        cookies["skadi_id"] = TRACKING_TOKEN

        log_in_as user
        post track_users_on_path

        assert_response :no_content
        assert_equal "1", response.cookies["skadi_track_user"]

        # User should be set on the visit on the next request
        get tracked_action_path
        assert_equal user, visit.reload.user
      end

      test "user opt out" do
        user = create :user
        visit = create :visit, user: user

        # Simulate a second visit with the same tracking user
        old_visit = create :visit, user: user

        cookies["skadi_track_user"] = "1"

        log_in_as user
        post track_users_off_path

        assert_response :no_content
        assert_equal 2, Skadi::Visit.count

        # Cookie is set
        assert_equal "0", response.cookies["skadi_track_user"]

        # User deleted from visits
        assert_nil visit.reload.user
        assert_nil old_visit.reload.user
      end
    end
  end
end

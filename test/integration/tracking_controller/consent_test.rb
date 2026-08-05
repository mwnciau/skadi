require "integration/test_case"

module Skadi::Integration
  module TrackingController
    # Tests that the tracking controller correctly handles consent changes, closely mimicking the `Skadi::Integration::ControllerDelegate::ConsentTest` tests; more thorough testing is done in unit tests for the ControllerDelegate class
    class ConsentTest < TestCase
      test "cookie consent" do
        # Create a new visit with a tracking token (representing an anonymity set)
        visit = create :visit, tracking_token: TRACKING_TOKEN
        view = create :view, visit: visit

        post skadi.tracking_endpoint_path, params: { view: view.token, consent: { cookie: true } }, as: :json

        assert_response :no_content

        # Check a new token is generated
        refute_equal TRACKING_TOKEN, response.cookies["skadi_id"]
        assert_match UUID_REGEX, response.cookies["skadi_id"]

        # Cookies enabled on visits
        assert visit.reload.cookies_enabled

        # Tracking cookie is set
        assert_equal response.cookies["skadi_id"], visit.reload.tracking_token
      end

      test "cookie opt out" do
        visit = create :visit, tracking_token: TRACKING_TOKEN, cookies_enabled: true
        view = create :view, visit: visit

        cookies["skadi_id"] = TRACKING_TOKEN

        post skadi.tracking_endpoint_path, params: { view: view.token, consent: { cookie: false } }, as: :json

        assert_response :no_content

        # Cookies disabled on visits
        refute visit.reload.cookies_enabled

        # Tracking cookie is deleted
        assert response.cookies.has_key?("skadi_id")
        assert_nil response.cookies["skadi_id"]
      end

      test "anonymity set consent" do
        view = create :view

        cookies["skadi_anonymity_set"] = "0"

        post skadi.tracking_endpoint_path, params: { view: view.token, consent: { anonymity_set: true } }, as: :json

        assert_response :no_content

        #  Sets cookie
        assert_equal "1", response.cookies["skadi_anonymity_set"]

        # Sets tracking token on visit
        assert_match UUID_REGEX, view.reload.visit.tracking_token
      end

      test "anonymity set opt out" do
        # Instead of trying to ensure we get the same anonymity set in the test, we just let the code create it for us
        cookies["skadi_anonymity_set"] = "1"
        get tracked_action_path

        visit = Skadi::Visit.first!
        view = Skadi::View.first!
        anonymity_set = visit.tracking_token

        # Simulate a second visit with the same anonymity set
        old_visit = create :visit, tracking_token: anonymity_set

        cookies["skadi_anonymity_set"] = "1"

        post skadi.tracking_endpoint_path, params: { view: view.token, consent: { anonymity_set: false } }, as: :json

        assert_response :no_content

        # Sets cookie
        assert_equal "0", response.cookies["skadi_anonymity_set"]

        # Ensure all visits using the anonymity set are removed
        refute_equal anonymity_set, visit.reload.tracking_token
        refute_equal anonymity_set, old_visit.reload.tracking_token
      end

      test "user consent" do
        user = create :user

        visit = create :visit, user: nil
        view = create :view, visit: visit

        cookies["skadi_track_user"] = "0"

        log_in_as user
        post skadi.tracking_endpoint_path, params: { view: view.token, consent: { user: true } }, as: :json

        assert_response :no_content
        assert_equal "1", response.cookies["skadi_track_user"]
      end

      test "user opt out" do
        user = create :user

        visit = create :visit, user: user
        view = create :view, visit: visit

        # Simulate a second visit with the same tracking user
        old_visit = create :visit, user: user

        cookies["skadi_track_user"] = "1"

        post skadi.tracking_endpoint_path, params: { view: view.token, consent: { user: false } }, as: :json

        assert_response :no_content

        # Cookie is set
        assert_equal "0", response.cookies["skadi_track_user"]

        # User deleted from visits
        assert_nil visit.reload.user
        assert_nil old_visit.reload.user
      end

      test "cookies are not changed with no consent" do
        view = create :view, visit: nil

        cookies["skadi_anonymity_set"] = "1"
        cookies["skadi_track_user"] = "0"
        cookies["skadi_id"] = TRACKING_TOKEN

        post skadi.tracking_endpoint_path, params: { view: view.token, consent: {} }, as: :json

        assert_response :no_content
        assert_equal "1", response.cookies["skadi_anonymity_set"]
        assert_equal "0", response.cookies["skadi_track_user"]
        assert_equal TRACKING_TOKEN, response.cookies["skadi_id"]
      end

      test "cookies are not changed with invalid consent" do
        view = create :view, visit: nil

        cookies["skadi_anonymity_set"] = "0"
        cookies["skadi_track_user"] = "1"
        cookies["skadi_id"] = TRACKING_TOKEN

        [
          {},
          { consent: 1 },
          { consent: { consent: true } },
          { consent: [ true ] },
        ].each do |invalid_params|
          post skadi.tracking_endpoint_path, params: { view: view.token, **invalid_params }, as: :json

          assert_response :no_content
          assert_equal "0", response.cookies["skadi_anonymity_set"]
          assert_equal "1", response.cookies["skadi_track_user"]
          assert_equal TRACKING_TOKEN, response.cookies["skadi_id"]
        end
      end
    end
  end
end

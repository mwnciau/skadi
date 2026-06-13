require "integration/test_case"

module Skadi::Integration
  module TrackingController
    class ConsentTest < TestCase
      UUID_REGEX = Skadi::Analytics::UUID_REGEX

      test "consent sets tracking cookie" do
        visit = create :visit, tracking_token: TRACKING_TOKEN
        view = create :view, visit: visit

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: true}, as: :json

        assert_response :no_content
        assert_equal TRACKING_TOKEN, response.cookies["skadi_id"]
      end

      test "consent sets tracking cookie without visit" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: true}, as: :json

        assert_response :no_content
        assert_match UUID_REGEX, response.cookies["skadi_id"]
      end

      test "consent updates existing visit with new tracking token" do
        visit = create :visit, tracking_token: nil
        view = create :view, visit: visit

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: true}, as: :json

        assert_response :no_content
        assert_match UUID_REGEX, visit.reload.tracking_token
      end

      test "consent clears opt out cookie" do
        view = create :view

        cookies["skadi_tracking_opt_out"] = "1"

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: true}, as: :json

        assert_response :no_content
        assert response.cookies.has_key?("skadi_tracking_opt_out")
        assert_nil response.cookies["skadi_tracking_opt_out"]
      end

      test "opt out sets opt out cookie" do
        visit = create :visit
        view = create :view, visit: visit

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: false}, as: :json

        assert_response :no_content
        assert_equal "1", response.cookies["skadi_tracking_opt_out"]
      end

      test "opt out sets opt out cookie without visit" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: false}, as: :json

        assert_response :no_content
        assert_equal "1", response.cookies["skadi_tracking_opt_out"]
      end

      test "opt out deletes tracking tokens in existing visits" do
        visit = create :visit, tracking_token: TRACKING_TOKEN
        view = create :view, visit: visit

        # Simulate a second visit with the same tracking token
        old_visit = create :visit, tracking_token: TRACKING_TOKEN

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: false}, as: :json

        assert_response :no_content
        assert_nil visit.reload.tracking_token
        assert_nil old_visit.reload.tracking_token
      end

      test "opt out deletes user in existing visits" do
        user = create :user
        ApplicationController.current_user = user

        visit = create :visit, user: user
        view = create :view, visit: visit

        # Simulate a second visit with the same tracking user
        old_visit = create :visit, user: user

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: false}, as: :json

        assert_response :no_content
        assert_nil visit.reload.user
        assert_nil old_visit.reload.user
      end

      test "opt out clears tracking cookie" do
        view = create :view

        cookies["skadi_id"] = TRACKING_TOKEN

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: false}, as: :json

        assert_response :no_content
        assert response.cookies.has_key?("skadi_id")
        assert_nil response.cookies["skadi_id"]
      end

      test "cookies are not changed with no consent" do
        view = create :view, visit: nil

        cookies["skadi_tracking_opt_out"] = "1"
        cookies["skadi_id"] = TRACKING_TOKEN

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: nil}, as: :json

        assert_response :no_content
        refute response.cookies.has_key?("skadi_tracking_opt_out")
        refute response.cookies.has_key?("skadi_id")
      end

      test "cookies are not changed with invalid consent" do
        view = create :view, visit: nil

        cookies["skadi_tracking_opt_out"] = "1"
        cookies["skadi_id"] = TRACKING_TOKEN

        [
          {},
          {consent: 1},
          {consent: {consent: true}},
          {consent: [true]},
        ].each do |invalid_params|
          post skadi.tracking_endpoint_path, params: {view: view.view_token, **invalid_params}, as: :json

          assert_response :no_content
          refute response.cookies.has_key?("skadi_tracking_opt_out")
          refute response.cookies.has_key?("skadi_id")
        end
      end
    end
  end
end

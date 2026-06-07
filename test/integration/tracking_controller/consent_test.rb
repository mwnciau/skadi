require "integration/test_case"

module Skadi::Integration
  module TrackingController
    class ConsentTest < TestCase
      TRACKING_TOKEN = "8cec5a7a-7bf7-403f-b15e-b2e45944182c"
      UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

      # ===============================================
      # Tracking cookie
      # ===============================================

      test "sets tracking cookie" do
        visit = create :visit, tracking_token: TRACKING_TOKEN
        view = create :view, visit: visit

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: {id: true}}, as: :json

        assert_response :no_content
        assert_equal TRACKING_TOKEN, response.cookies["skadi_id"]
      end

      test "sets tracking cookie without visit" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: {id: true}}, as: :json

        assert_response :no_content
        assert_match UUID_REGEX, response.cookies["skadi_id"]
      end

      test "clears tracking cookie" do
        visit = create :visit, tracking_token: TRACKING_TOKEN
        view = create :view, visit: visit

        cookies["skadi_id"] = TRACKING_TOKEN

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: {id: false}}, as: :json

        assert_response :no_content
        assert_nil response.cookies["skadi_id"]
      end

      test "leaves tracking cookie" do
        visit = create :visit, tracking_token: TRACKING_TOKEN
        view = create :view, visit: visit
        cookies["skadi_id"] = TRACKING_TOKEN

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: {}}, as: :json

        assert_response :no_content
        refute response.cookies.has_key?("skadi_id")
      end

      # ===============================================
      # Tracking opt out
      # ===============================================

      test "opt out" do
        visit = create :visit, tracking_token: TRACKING_TOKEN
        view = create :view, visit: visit

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: {opt_out: true}}, as: :json

        assert_response :no_content
        assert_equal "1", response.cookies["skadi_tracking_opt_out"]
        refute_equal TRACKING_TOKEN, visit.reload.tracking_token
      end

      test "opt out without visit" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: {opt_out: true}}, as: :json

        assert_response :no_content
        assert_equal "1", response.cookies["skadi_tracking_opt_out"]
      end

      test "clears opt out" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: {opt_out: false}}, as: :json

        assert_response :no_content
        assert_nil response.cookies["skadi_tracking_opt_out"]
      end

      test "leaves opt out cookie" do
        view = create :view, visit: nil
        cookies["skadi_tracking_opt_out"] = "1"

        post skadi.tracking_endpoint_path, params: {view: view.view_token, consent: {}}, as: :json

        assert_response :no_content
        refute response.cookies.has_key?("skadi_tracking_opt_out")
      end
    end
  end
end

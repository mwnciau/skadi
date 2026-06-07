require "integration/test_case"

module Skadi::Integration
  module TrackingController
    class TrackingControllerTest < TestCase
      test "verifies visit and view" do
        visit = create :visit
        view = create :view, visit: visit

        post skadi.tracking_endpoint_path, params: {view: view.view_token}, as: :json

        assert_response :no_content
        assert visit.reload.verified?
        assert view.reload.verified?
      end

      test "verifies view without visit" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: {view: view.view_token}, as: :json

        assert_response :no_content
        assert view.reload.verified?
      end

      test "bad request when missing view token" do
        post skadi.tracking_endpoint_path

        assert_response :bad_request
      end

      test "not found when invalid view token" do
        post skadi.tracking_endpoint_path, params: {view: "00000000-0000-0000-0000-000000000000"}, as: :json

        assert_response :not_found
      end

      test "tracking payload size is limited" do
        Skadi.configuration.max_tracking_payload_size = 100
        post skadi.tracking_endpoint_path, params: {token: "0123456789" * 11}, as: :json

        assert_response :content_too_large
        parsed_json = JSON.parse(response.body)
        assert_equal "Payload too large", parsed_json["error"]
      end
    end
  end
end

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

      test "bad request when invalid view token" do
        [
          nil,
          123,
          true,
        ].each do |invalid_token|
          post skadi.tracking_endpoint_path, params: {view: invalid_token}, as: :json

          assert_response :bad_request
        end
      end

      test "not found when non-existent view token" do
        post skadi.tracking_endpoint_path, params: {view: "00000000-0000-0000-0000-000000000000"}, as: :json

        assert_response :not_found
      end

      test "view token expires" do
        view = create :view, created_at: Time.current.change(hour: 9, min: 0, sec: 0)

        travel_to Time.current.change(hour: 10, min: 59, sec: 59) do
          post skadi.tracking_endpoint_path, params: {view: view.view_token}, as: :json

          assert_response :no_content
        end

        travel_to Time.current.change(hour: 11, min: 0, sec: 0) do
          post skadi.tracking_endpoint_path, params: {view: view.view_token}, as: :json

          assert_response :gone
        end
      end

      test "view token expiry time is changed by visit duration" do
        Skadi.configuration.visit_duration = 4.hours
        view = create :view, created_at: Time.current.change(hour: 9, min: 0, sec: 0)

        travel_to Time.current.change(hour: 12, min: 59, sec: 59) do
          post skadi.tracking_endpoint_path, params: {view: view.view_token}, as: :json

          assert_response :no_content
        end

        travel_to Time.current.change(hour: 13, min: 0, sec: 0) do
          post skadi.tracking_endpoint_path, params: {view: view.view_token}, as: :json

          assert_response :gone
        end
      end

      test "tracking payload size is limited" do
        Skadi.configuration.max_tracking_payload_size = 100
        post skadi.tracking_endpoint_path, params: {token: "0123456789" * 11}, as: :json

        assert_response :content_too_large
        parsed_json = JSON.parse(response.body)
        assert_equal "Payload too large", parsed_json["error"]
      end

      test "tracking payload size is rate limited" do
        view = create :view

        61.times do |it|
          post skadi.tracking_endpoint_path, params: {
            view: view.view_token,
            events: [{name: "test#{it}", properties: {}}],
          }, as: :json
        end

        assert_response :too_many_requests
        assert_equal 60, Skadi::Event.count

        # N.times start at 0, so 60 is the 61st request
        refute Skadi::Event.where(name: "test60").exists?
      end

      test "rate limiting resets after a minute" do
        view = create :view

        61.times do |it|
          post skadi.tracking_endpoint_path, params: {
            view: view.view_token,
            events: [{name: "test#{it}", properties: {}}],
          }, as: :json
        end

        travel 61.seconds do
          post skadi.tracking_endpoint_path, params: {
            view: view.view_token,
            events: [{name: "test61", properties: {}}],
          }, as: :json
        end

        assert_response :no_content
        assert_equal 61, Skadi::Event.count
        assert Skadi::Event.where(name: "test61").exists?
      end
    end
  end
end

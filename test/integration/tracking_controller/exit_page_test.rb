require "integration/test_case"

module Skadi::Integration
  module TrackingController
    class ExitPageTest < TestCase
      test "tracks exit page" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: { view: view.view_token, exit_page: "https://example.com" }, as: :json

        assert_response :no_content
        assert_equal "https://example.com", view.reload.exit_page
      end

      test "does not track invalid exit page" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: { view: view.view_token, exit_page: 4 }, as: :json

        assert_response :no_content
        assert_nil view.reload.exit_page
      end

      test "does not overwrite exit page" do
        view = create :view, visit: nil, exit_page: "https://example.com"

        post skadi.tracking_endpoint_path, params: { view: view.view_token, exit_page: nil }, as: :json

        assert_response :no_content
        assert_equal "https://example.com", view.reload.exit_page
      end
    end
  end
end

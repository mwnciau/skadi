require "integration/test_case"

module Skadi::Integration
  class AssetControllerTest < TestCase
    test "tracking script" do
      get skadi.tracking_script_path

      assert_response :ok

      assert_match "navigator.sendBeacon", response.body

      # The script content should be about 1-2KB
      assert response.body.length > 1_024
      assert response.body.length < 2_048

      assert_equal "text/javascript", headers["content-type"]
      assert_match "max-age=31556952", headers["cache-control"]
      assert_nil headers["content-disposition"]
    end
  end
end

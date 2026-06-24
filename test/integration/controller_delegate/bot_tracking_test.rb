require "integration/test_case"

module Skadi::Integration
  module ControllerDelegate
    class BotTrackingTest < TestCase
      test "bots are tracked when enabled by configuration" do
        Skadi.configuration.track_bots = true
        cookies[:skadi_id] = TRACKING_TOKEN

        get simple_event_path

        assert_response :ok

        assert_equal 1, Skadi::Visit.count
        assert_equal 1, Skadi::View.count
        assert_equal 1, Skadi::Event.count

        # Browser demographics are logged
        assert_equal 5, Skadi::Demographic.count
      end

      test "bots are not tracked" do
        Skadi.configuration.track_bots = false
        cookies[:skadi_id] = TRACKING_TOKEN

        get simple_event_path

        assert_response :ok

        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
        assert_equal 0, Skadi::Event.count
        assert_equal 0, Skadi::Demographic.count
      end
    end
  end
end

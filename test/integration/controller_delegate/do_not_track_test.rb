require "integration/test_case"

module Skadi::Integration
  module ControllerDelegate
    class DoNotTrackTest < TestCase
      test "action level do_not_track! stops tracking" do
        get untracked_action_path

        assert_response :ok
        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
      end

      test "controller level do_not_track! stops tracking" do
        get untracked_controller_path

        assert_response :ok
        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
      end

      test "controller level do_not_track! with kwargs stops tracking" do
        get untracked_controller_with_kwargs_path

        assert_response :ok
        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
      end

      test "do_not_track! mid-action discards queued events and demographics" do
        cookies[:skadi_id] = TRACKING_TOKEN

        get queue_then_untrack_path

        assert_response :ok
        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
        assert_equal 0, Skadi::Event.count
        assert_equal 0, Skadi::Demographic.count
      end
    end
  end
end

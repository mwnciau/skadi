require "integration/test_case"

module Skadi::Integration
  module Analytics
    class DoNotTrackTest < TestCase
      test "action level do_not_track! stops tracking" do
        get untracked_action_path

        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
      end

      test "controller level do_not_track! stops tracking" do
        get untracked_controller_path

        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
      end

      test "controller level do_not_track! with kwargs stops tracking" do
        get untracked_controller_with_kwargs_path

        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
      end
    end
  end
end

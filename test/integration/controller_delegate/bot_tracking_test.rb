require "integration/test_case"

module Skadi::Integration
  module ControllerDelegate
    class BotTrackingTest < TestCase
      HUMAN_HEADERS = {
        "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " \
          "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      }

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
        get simple_demographic_path

        assert_response :ok

        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
        assert_equal 0, Skadi::Event.count
        assert_equal 0, Skadi::Demographic.count
      end

      test "bots are counted when enabled by configuration" do
        Skadi.configuration.track_bots = false
        Skadi.configuration.count_bots = true

        # Counts when no visit is created
        get simple_event_path
        assert_equal 0, Skadi::Visit.count
        assert_bot_count bots: 1

        # Counts humans with a visit
        cookies[:skadi_id] = TRACKING_TOKEN
        get simple_event_path, headers: HUMAN_HEADERS
        assert_equal 1, Skadi::Visit.count
        assert_bot_count bots: 1, humans: 1

        # Counts when bots are tracked
        Skadi.configuration.track_bots = true
        get tracked_action_path
        assert_bot_count bots: 2, humans: 1

        # Count is disabled by do_not_track!
        get untracked_action_path
        get untracked_controller_path
        assert_bot_count bots: 2, humans: 1
      end

      test "bots are not counted when disabled by configuration" do
        Skadi.configuration.count_bots = false

        # When no visit is created
        get simple_event_path
        assert_equal 0, Skadi::Visit.count

        # When a visit is created
        cookies[:skadi_id] = TRACKING_TOKEN
        get simple_event_path
        assert_equal 1, Skadi::Visit.count

        # Human traffic
        cookies[:skadi_id] = TRACKING_TOKEN
        get simple_event_path, headers: HUMAN_HEADERS

        get untracked_action_path
        get untracked_controller_path

        assert_bot_count bots: 0, humans: 0
      end

      private def assert_bot_count(bots: 0, humans: 0)
        bot_actual = Skadi::Demographic.where(name: "Traffic type", value: "Bot").sum(:count) || 0
        human_actual = Skadi::Demographic.where(name: "Traffic type", value: "Human").sum(:count) || 0

        assert_equal "#{bots} bots, #{humans} humans",
          "#{bot_actual} bots, #{human_actual} humans",
          "Expected #{bots} bots and #{humans} humans but got #{bot_actual} bots and #{human_actual} humans at #{caller.first}"
      end
    end
  end
end

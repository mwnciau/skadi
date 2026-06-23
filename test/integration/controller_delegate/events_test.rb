require "integration/test_case"

module Skadi::Integration
  module ControllerDelegate
    class EventsTest < TestCase
      test "simple event" do
        cookies["skadi_id"] = TRACKING_TOKEN

        get simple_event_path

        assert_response :ok

        assert_equal 1, Skadi::Event.count
        event = Skadi::Event.first!
        assert_equal "simple_event", event.name
        assert_equal({"property" => "value"}, event.properties)

        refute_nil event.visit
        refute_nil event.view
      end

      test "multiple events" do
        cookies["skadi_id"] = TRACKING_TOKEN

        get multiple_events_path

        assert_response :ok

        assert_equal 2, Skadi::Event.count
        simple_event = Skadi::Event.first!
        sensitive_event = Skadi::Event.last!

        assert_equal "simple_event", simple_event.name
        assert_equal({}, simple_event.properties)

        assert_equal "sensitive_event", sensitive_event.name
        assert_equal({"sensitive_data" => "sensitive"}, sensitive_event.properties)

        # Ensure the event has not been linked to a visit or view
        assert_nil sensitive_event.visit
        assert_nil sensitive_event.view

        # Ensure the event time has been redacted
        assert_equal Time.current.beginning_of_day, sensitive_event.created_at
      end
    end
  end
end

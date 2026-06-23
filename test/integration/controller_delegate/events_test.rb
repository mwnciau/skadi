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
        assert_equal({}, event.properties)

        refute_nil event.visit
        refute_nil event.view
      end

      test "event with properties" do
        get with_properties_event_path

        assert_response :ok

        assert_equal 1, Skadi::Event.count
        event = Skadi::Event.first!
        assert_equal "with_properties_event", event.name
        assert_equal({"property" => "value"}, event.properties)
      end

      test "sensitive event" do
        cookies["skadi_id"] = TRACKING_TOKEN

        get sensitive_event_path

        assert_response :ok

        assert_equal 1, Skadi::Event.count
        event = Skadi::Event.first!
        assert_equal "sensitive_event", event.name
        assert_equal({"sensitive_data" => "sensitive"}, event.properties)

        # Ensure the event has not been linked to a visit or view
        assert_nil event.visit
        assert_nil event.view

        # Ensure the event time has been redacted
        assert_equal Time.current.beginning_of_day, event.created_at
      end

      test "multiple event" do
        get multiple_events_path

        assert_response :ok

        assert_equal 2, Skadi::Event.count
        event_1 = Skadi::Event.first!
        event_2 = Skadi::Event.last!
        assert_equal "multiple_event", event_1.name
        assert_equal "multiple_event", event_2.name
        assert_equal({"number" => 1}, event_1.properties)
        assert_equal({"number" => 2}, event_2.properties)
      end
    end
  end
end

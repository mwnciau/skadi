require "integration/test_case"

module Skadi::Integration
  module TrackingController
    class EventsTest < TestCase
      test "tracks events" do
        visit = create :visit
        view = create :view, visit: visit

        post skadi.tracking_endpoint_path, params: { view: view.view_token, events: [
          {name: "my event", properties: {}},
          {name: "my event with properties", properties: {key: "value"}},
        ] }, as: :json

        assert_response :no_content
        assert_equal 2, Skadi::Event.count

        events = Skadi::Event.all

        assert_equal "my event", events.first.name
        assert_equal visit, events.first.visit
        assert_equal view, events.first.view
        assert_equal({}, events.first.properties)

        assert_equal "my event with properties", events.last.name
        assert_equal visit, events.last.visit
        assert_equal view, events.last.view
        assert_equal({"key" => "value"}, events.last.properties)
      end

      test "tracks events without visit" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: { view: view.view_token, events: [
          {name: "my event", properties: {}},
        ] }, as: :json

        assert_response :no_content
        assert_equal 1, Skadi::Event.count

        event = Skadi::Event.first!

        assert_equal "my event", event.name
        assert_nil event.visit
        assert_equal view, event.view
        assert_equal({}, event.properties)
      end

      test "ignores invalid events" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: { view: view.view_token, events: [
          {properties: {}},
          {name: "", properties: {}},
          {name: "event"},
          {name: "event", properties: "string"},
          {name: "valid event", properties: {}},
        ] }, as: :json

        assert_response :no_content
        assert_equal 1, Skadi::Event.count

        event = Skadi::Event.first!

        assert_equal "valid event", event.name
        assert_nil event.visit
        assert_equal view, event.view
        assert_equal({}, event.properties)
      end

      test "non-array passed to events" do
        view = create :view, visit: nil

        post skadi.tracking_endpoint_path, params: { view: view.view_token, events: "not an array" }, as: :json

        assert_response :no_content
        assert_equal 0, Skadi::Event.count
      end
    end
  end
end

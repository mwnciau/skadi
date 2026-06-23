require_relative "test_case"
require "factory_bot_rails"

module Skadi::Unit
  class EventTest < TestCase
    include FactoryBot::Syntax::Methods

    setup do
      @visit = create(:visit)
      @view = create(:view, visit: @visit)
    end

    test "redact_and_upsert creates a row linked to the visit and view" do
      Skadi::Event.redact_and_insert(
        [{name: "click", properties: {target: "button"}}],
        visit: @visit,
        view: @view,
      )

      assert_equal 1, Skadi::Event.count

      event = Skadi::Event.first!
      assert_equal "click", event.name
      assert_equal({"target" => "button"}, event.properties)
      assert_equal @visit.id, event.visit_id
      assert_equal @view.id, event.view_id
      assert_in_delta Time.current.to_f, event.created_at.to_f, 5
    end

    test "redact_and_upsert with a nil visit still records the event against the view" do
      Skadi::Event.redact_and_insert(
        [{name: "click", properties: {}}],
        visit: nil,
        view: @view,
      )

      event = Skadi::Event.first!
      assert_nil event.visit_id
      assert_equal @view.id, event.view_id
    end

    test "redact_and_upsert redacts sensitive events" do
      Skadi::Event.redact_and_insert(
        [{name: "password_reset", properties: {}, sensitive: true}],
        visit: @visit,
        view: @view,
      )

      event = Skadi::Event.first!
      assert_nil event.visit_id
      assert_nil event.view_id
      assert_equal Time.current.beginning_of_day, event.created_at
    end

    test "redact_and_upsert strips the :sensitive key from the persisted row when set to false" do
      # If `:sensitive` leaks through to insert_all, ActiveRecord raises UnknownAttributeError
      # because there's no `sensitive` column.
      assert_nothing_raised do
        Skadi::Event.redact_and_insert(
          [{name: "click", properties: {}, sensitive: false}],
          visit: @visit,
          view: @view,
        )
      end

      assert_equal 1, Skadi::Event.count
    end

    test "redact_and_upsert inserts multiple events in a single call" do
      Skadi::Event.redact_and_insert(
        [
          {name: "click", properties: {n: 1}},
          {name: "scroll", properties: {n: 2}},
        ],
        visit: @visit,
        view: @view,
      )

      assert_equal 2, Skadi::Event.count
      event_1 = Skadi::Event.first!
      event_2 = Skadi::Event.last!

      assert_equal "click", event_1.name
      assert_equal({"n" => 1}, event_1.properties)
      assert_equal "scroll", event_2.name
      assert_equal({"n" => 2}, event_2.properties)
    end

    test "redact_and_upsert handles mixed sensitivity in one call" do
      Skadi::Event.redact_and_insert(
        [
          {name: "click", properties: {}},
          {name: "password_reset", properties: {}, sensitive: true},
        ],
        visit: @visit,
        view: @view,
      )

      assert_equal 2, Skadi::Event.count
      non_sensitive = Skadi::Event.first!
      sensitive = Skadi::Event.last!

      assert_equal @visit.id, non_sensitive.visit_id
      assert_equal @view.id, non_sensitive.view_id
      assert_in_delta Time.current.to_f, non_sensitive.created_at.to_f, 5

      assert_nil sensitive.visit_id
      assert_nil sensitive.view_id
      assert_equal Time.current.beginning_of_day, sensitive.created_at
    end

    test "redact_and_upsert handles mixed sensitivity in reverse order" do
      # `insert_all` requires all entries to have the same set of keys. Now, this raises an error,
      # but in previous versions of Rails this silently failed to insert all the data.
      Skadi::Event.redact_and_insert(
        [
          {name: "password_reset", properties: {}, sensitive: true},
          {name: "click", properties: {}},
        ],
        visit: @visit,
        view: @view,
      )

      non_sensitive = Skadi::Event.last!
      assert_equal @visit.id, non_sensitive.visit_id
      assert_equal @view.id, non_sensitive.view_id
    end
  end
end

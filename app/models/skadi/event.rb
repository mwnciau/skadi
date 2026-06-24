module Skadi
  class Event < ApplicationRecord
    belongs_to :visit, class_name: "Skadi::Visit", optional: true, inverse_of: :events
    belongs_to :view, class_name: "Skadi::View", optional: true, inverse_of: :events

    validates :name, presence: true

    # Redacts events that are marked as sensitive
    def self.redact_and_insert(events, view:, visit:)
      events.each do |event|
        # Note: both paths must have the same set of keys, which is a requirement for upsert_all
        if event[:sensitive]
          event[:view_id] = nil
          event[:visit_id] = nil

          # Sensitive events should have their created date redacted so they cannot be linked to views/visits based on timings
          event[:created_at] = Time.current.beginning_of_day
        else
          # Attach events to the current visit and view, only if it is not marked as sensitive
          event[:view_id] = view.id
          event[:visit_id] = visit&.id
          event[:created_at] = Time.current
        end

        event[:name] = event[:name].strip[0, 255]

        event.delete(:sensitive)
      end

      Event.insert_all(events)
    end
  end
end

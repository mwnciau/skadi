class EventsController < ApplicationController
  def simple
    skadi.event("simple_event", {property: "value"})

    head :ok
  end

  def multiple
    skadi.event("simple_event")
    skadi.event("sensitive_event", {sensitive_data: "sensitive"}, sensitive: true)

    head :ok
  end
end

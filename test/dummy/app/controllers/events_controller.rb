class EventsController < ApplicationController
  def simple
    skadi.event("simple_event")

    head :ok
  end

  def with_properties
    skadi.event("with_properties_event", { property: "value" })

    head :ok
  end

  def sensitive
    skadi.event("sensitive_event", { sensitive_data: "sensitive" }, sensitive: true)

    head :ok
  end

  def multiple
    skadi.event("multiple_event", {number: 1})
    skadi.event("multiple_event", {number: 2})

    head :ok
  end

  def mixed_sensitivity
    skadi.event("simple_event")
    skadi.event("sensitive_event", { sensitive_data: "sensitive" }, sensitive: true)

    head :ok
  end
end

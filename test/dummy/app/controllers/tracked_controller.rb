class TrackedController < ApplicationController
  do_not_track! only: :untracked_controller_with_kwargs

  def tracked_action
    head :ok
  end

  # An action that calls do_not_track! in the body
  def untracked_action
    do_not_track!

    head :ok
  end

  # An action that has tracking disabled by a controller-level `do_not_track!` using the `:only` kwarg
  def untracked_controller_with_kwargs
    head :ok
  end

  # An action that queues an event and a demographic, then calls do_not_track!
  def queue_then_untrack
    skadi.event("queued_event")
    skadi.demographic("queued", "demographic")
    skadi.do_not_track!

    head :ok
  end

  def test_action
  end
end

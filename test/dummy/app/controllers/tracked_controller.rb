class TrackedController < ApplicationController
  do_not_track! only: :do_not_track_controller_with_kwargs

  def tracked_action
    head :ok
  end

  # An action that calls do_not_track! in the body
  def do_not_track_action
    do_not_track!

    head :ok
  end

  # An action that calls do_not_track! in the body
  def do_not_track_controller_with_kwargs
    head :ok
  end

  def test_action
  end
end

class TrackedController < ApplicationController
  def tracked_action
    head :ok
  end

  # An action that calls do_not_track! in the body
  def do_not_track_action
    do_not_track!

    head :ok
  end
end

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

  def test_action
  end
end

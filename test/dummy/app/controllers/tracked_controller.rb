class ExampleController < ApplicationController
  def tracked_action
    head :ok
  end

  def do_not_track_action
    do_not_track!

    head :ok
  end
end

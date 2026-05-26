# A controller that calls do_not_track! in the class definition
class DoNotTrackController < ApplicationController
  do_not_track!

  def do_not_track_controller
    head :ok
  end
end

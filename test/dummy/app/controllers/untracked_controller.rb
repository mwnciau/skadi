# A controller that calls do_not_track! in the class definition
class UntrackedController < ApplicationController
  do_not_track!

  def untracked_controller
    head :ok
  end
end

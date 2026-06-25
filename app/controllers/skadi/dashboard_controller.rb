module Skadi
  class DashboardController < ::ApplicationController
    do_not_track! if defined?(do_not_track!)

    def show
      render :show
    end
  end
end

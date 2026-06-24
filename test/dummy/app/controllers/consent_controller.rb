class ConsentController < ApplicationController
  def consent
    skadi.consent!

    head :ok
  end

  def opt_out
    skadi.opt_out!

    head :ok
  end
end

class DemographicsController < ApplicationController
  def simple
    skadi.demographic("demographic", "simple")

    head :ok
  end

  def multiple
    skadi.demographic("demographic", "simple")
    skadi.demographic("demographic", "view", action_specific: true)

    head :ok
  end
end

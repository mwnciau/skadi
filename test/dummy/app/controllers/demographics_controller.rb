class DemographicsController < ApplicationController
  def simple
    skadi.demographic("demographic", "simple")

    head :ok
  end

  def multiple
    skadi.demographic("demographic", "multiple_1")
    skadi.demographic("demographic", "multiple_2")
    skadi.demographic("demographic", "multiple_2")

    head :ok
  end

  def view
    skadi.demographic("demographic", "view", true)

    head :ok
  end

  def mixed_specificity
    skadi.demographic("demographic", "simple")
    skadi.demographic("demographic", "view", true)

    head :ok
  end
end

module Skadi
  class Demographic < ApplicationRecord
    self.implicit_order_column = :recorded_on

    validates :metric_name, presence: true
    validates :metric_value, presence: true

    validates :recorded_on, presence: true
  end
end

module Skadi
  class Demographic < ApplicationRecord
    self.implicit_order_column = :recorded_on

    validates :name, presence: true
    validates :value, presence: true

    validates :recorded_on, presence: true
  end
end

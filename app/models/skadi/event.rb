module Skadi
  class Event < ApplicationRecord
    belongs_to :visit, class_name: "Skadi::Visit", optional: true, inverse_of: :events
    belongs_to :view, class_name: "Skadi::View", optional: true, inverse_of: :events

    validates :name, presence: true
  end
end

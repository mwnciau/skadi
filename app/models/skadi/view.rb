module Skadi
  class View < ApplicationRecord
    belongs_to :visit, class_name: "Skadi::Visit", optional: true, inverse_of: :views

    has_many :events, class_name: "Skadi::Event", inverse_of: :view
  end
end

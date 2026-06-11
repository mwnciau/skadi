module Skadi
  class Visit < ApplicationRecord
    has_many :views, class_name: "Skadi::View", inverse_of: :visit
    has_many :events, class_name: "Skadi::Event", inverse_of: :visit
  end
end

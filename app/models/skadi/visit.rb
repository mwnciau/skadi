module Skadi
  class Visit < ApplicationRecord
    has_many :views, class_name: "Skadi::View", inverse_of: :visit
    has_many :events, class_name: "Skadi::Event", inverse_of: :visit

    before_create :populate_visit_token

    private def populate_visit_token
      self.visit_token ||= SecureRandom.uuid_v7
    end
  end
end

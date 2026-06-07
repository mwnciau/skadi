module Skadi
  class Visit < ApplicationRecord
    has_many :views, class_name: "Skadi::View", inverse_of: :visit
    has_many :events, class_name: "Skadi::Event", inverse_of: :visit

    before_create :populate_defaults

    private def populate_defaults
      self.verified = false
      self.visit_token ||= SecureRandom.uuid_v7
    end
  end
end

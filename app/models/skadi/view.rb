module Skadi
  class View < ApplicationRecord
    belongs_to :visit, class_name: "Skadi::Visit", optional: true, inverse_of: :views

    has_many :events, class_name: "Skadi::Event", inverse_of: :view

    validates :path, presence: true

    before_create :populate_defaults

    private def populate_defaults
      self.verified = false
      self.view_token ||= SecureRandom.uuid_v7
    end
  end
end

module Skadi
  class Visit < ApplicationRecord
    has_many :views, class_name: "Skadi::View", inverse_of: :visit
    has_many :events, class_name: "Skadi::Event", inverse_of: :visit

    def self.find_active_visit_for(tracking_token, user)
      visit_query = nil
      if tracking_token
        visit_query = where(tracking_token: tracking_token)
          .and(where("created_at > ?", Skadi.configuration.visit_duration.ago))
      end
      if user
        user_visit_query = where(user_id: user.id)
          .and(where("created_at > ?", Skadi.configuration.visit_duration.ago))

        visit_query = visit_query ? visit_query.or(user_visit_query) : user_visit_query
      end

      visit_query&.first
    end
  end
end

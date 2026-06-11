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
      if user&.persisted?
        user_visit_query = where(user_id: user.id)
          .and(where("created_at > ?", Skadi.configuration.visit_duration.ago))

        visit_query = visit_query ? visit_query.or(user_visit_query) : user_visit_query
      end

      visit = visit_query&.order(created_at: :desc)&.limit(1)&.first

      # If the user has changed since the last visit, create a new visit
      return nil if visit&.user && user&.persisted? && visit.user != user

      visit
    end

    # @param tracking_token [String, nil]
    # @param user [ActiveModel::Model, nil]
    # @param request [ActionDispatch::Request]
    # @return [Skadi::Visit]
    def self.build_from(tracking_token, user, request)
      visit = new

      visit.visit_token = SecureRandom.uuid_v7
      visit.tracking_token = tracking_token
      visit.user_id = user&.id

      visit.referrer = Skadi::Url.redact_and_normalise_url(request.referrer)
      visit.landing_page = Skadi::Url.view_path_from_request(request)

      visit.utm_source = request.query_parameters["utm_source"]
      visit.utm_medium = request.query_parameters["utm_medium"]
      visit.utm_term = request.query_parameters["utm_term"]
      visit.utm_content = request.query_parameters["utm_content"]
      visit.utm_campaign = request.query_parameters["utm_campaign"]

      visit.verified = false

      visit
    end
  end
end

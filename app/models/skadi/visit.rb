module Skadi
  class Visit < ApplicationRecord
    has_many :views, class_name: "Skadi::View", inverse_of: :visit
    has_many :events, class_name: "Skadi::Event", inverse_of: :visit

    def token = visit_token

    def self.find_active_visit_for(tracking_token, user)
      return nil if tracking_token.nil? && user.nil?

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
      return nil if visit&.user_id && user&.persisted? && visit.user_id != user.id

      visit
    end

    # @param tracking_token [String, nil]
    # @param user [ActiveModel::Model, nil]
    # @param request [ActionDispatch::Request]
    # @return [Skadi::Visit]
    def self.build_from(tracking_token, user_id = nil, request = nil, cookies_enabled: nil)
      if cookies_enabled.nil?
        cookies_enabled = request&.cookie_jar&.key?("skadi_id") || false
      end

      new(
        visit_token: SecureRandom.uuid_v7,
        tracking_token: tracking_token,
        user_id: user_id,

        referrer: request ? Skadi::Url.redact_and_normalise_url(request.referrer, request: request) : nil,
        landing_page: request ? Skadi::Url.view_path_from_request(request) : nil,

        utm_source: request ? request.query_parameters["utm_source"] : nil,
        utm_medium: request ? request.query_parameters["utm_medium"] : nil,
        utm_term: request ? request.query_parameters["utm_term"] : nil,
        utm_content: request ? request.query_parameters["utm_content"] : nil,
        utm_campaign: request ? request.query_parameters["utm_campaign"] : nil,

        verified: false,
        cookies_enabled: cookies_enabled,
      )
    end
  end
end

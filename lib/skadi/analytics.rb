# Adds Skadi Analytics helper methods to your controller, and enabled automatic tracking if configured.
module Skadi
  module Analytics
    extend ActiveSupport::Concern

    included do
      before_action :track_visit
      before_action :track_view
    end

    # @!method request
    #   @return [ActionDispatch::Request]
    # @!method params
    #   @return [ActionController::Parameters]
    # @!method cookies
    #   @return [ActionDispatch::Cookies::CookieJar]

    def track_visit
      tracking_token = Skadi::Analytics.calculate_tracking_token(request.remote_ip, request.user_agent)

      has_utm_params = params.keys.any? { |it| it.to_s.start_with?("utm_") }
      has_external_referrer = request.referer.present? && !request.referer.include?(request.host)
      user = Skadi.configuration.user_method ? send(Skadi.configuration.user_method) : nil

      # Only create a visit if we have some useful data or way of tracking users across pages
      return unless @tracking_token || cookies[:skadi_id] || user || has_utm_params || has_external_referrer

      existing_visit = Skadi::Visit.where()
    end

    # Generates a unique token for the given IP and user agent
    # @return [String]
    def self.calculate_tracking_token(ip, user_agent)
      return nil unless Skadi.configuration.use_anonymisation_sets

      user_fingerprint = "#{ip}|#{user_agent}"

      hash = OpenSSL::HMAC.hexdigest("sha256", anonymity_set_pepper, user_fingerprint)

      # We want a UUID-like string to be compatible with the uuid type if the database is PostgreSQL, but don't need a valid UUID
      "#{hash[0, 8]}-#{hash[8, 4]}-#{hash[12, 4]}-#{hash[16, 4]}-#{hash[20, 12]}"
    end

    # return [String]
    def self.anonymity_set_pepper
      "abcde"
    end
  end
end

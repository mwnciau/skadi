# Adds Skadi Analytics helper methods to your controller, and enabled automatic tracking if configured.
module Skadi::Analytics
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
    @visitor_token = Skadi::Analytics.calculate_visitor_token(request.remote_ip, request.user_agent)

    has_utm_params = params.keys.any? { it.to_s.start_with?("utm_") }
    has_external_referrer = request.referer.present? && !request.referer.include?(request.host)
    user = Skadi.configuration.user_method ? send(Skadi.configuration.user_method) : nil

    # Only create a visit if we have some useful data or way of tracking users across pages
    return unless @visitor_token || cookies[:skadi_id] || user || has_utm_params || has_external_referrer

    existing_visit = Skadi::Visit.where()
  end

  # Generates a unique token for the given IP and user agent
  # @return [String]
  def self.calculate_visitor_token(ip, user_agent)
    return nil unless Skadi.configuration.use_anonymisation_sets

    user_fingerprint = "#{ip}|#{user_agent}"

    OpenSSL::HMAC.hexdigest("sha256", anonymity_set_pepper, user_fingerprint)

    # We want a UUID-like string to be compatible with Postgres' uuid field, but don't need a valid UUID
    "#{hex[0, 8]}-#{hex[8, 4]}-#{hex[12, 4]}-#{hex[16, 4]}-#{hex[20, 12]}"
  end

  # return [String]
  def self.anonymity_set_pepper
    "abcde"
  end
end

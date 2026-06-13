# Adds Skadi Analytics helper methods to your controller, and enabled automatic tracking if configured.
module Skadi
  module Analytics
    extend ActiveSupport::Concern

    UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

    included do
      before_action :track_visit, :track_view

      after_action :skadi_persist

      # Make these methods available in the view for when we output the frontend script
      helper_method :skadi_visit, :skadi_view

      # Add the Skadi view helper methods
      helper Skadi::ApplicationHelper

      # Disable Skadi tracking for the current controller
      def self.do_not_track!(**kwargs)
        skip_before_action :track_visit, :track_view, **kwargs
      end
    end

    # @!method request
    #   @return [ActionDispatch::Request]
    # @!method params
    #   @return [ActionController::Parameters]
    # @!method cookies
    #   @return [ActionDispatch::Cookies::CookieJar]

    # Expose the visit and view to the controller
    attr_reader :skadi_visit, :skadi_view

    # Disable Skadi tracking for the current request
    def do_not_track!
      @skadi_do_not_track = true
    end

    # Whether Skadi tracking has been disabled for the current request
    # @return [Boolean]
    def do_not_track?
      !!@skadi_do_not_track
    end

    # Called before the action to find or build the Skadi visit model
    def track_visit
      tracking_token, user, has_utm_params, has_external_referrer = nil

      skadi_id = cookies["skadi_id"]
      consent = skadi_id.present?

      # If the user has opted out of tracking, we do not use cookies or anonymity sets
      unless cookies["skadi_tracking_opt_out"] == "1"
        # Ensure the cookie is a UUID as expected
        cookie_id = skadi_id&.match(UUID_REGEX) ? skadi_id : nil
        tracking_token = cookie_id || AnonymitySet.calculate(request.remote_ip, request.user_agent)

        # Only track the user if we have consent
        if consent
          user = Skadi.configuration.user_method ? send(Skadi.configuration.user_method) : nil
        end

        @skadi_visit = Skadi::Visit.find_active_visit_for(tracking_token, user)

        # Update the user if the user has logged in since the last view
        @skadi_visit.user = user if @skadi_visit && @skadi_visit.user.nil?

        return if @skadi_visit
      end

      unless tracking_token || user
        has_utm_params = params.keys.any? { |it| it.to_s.start_with?("utm_") }
        has_external_referrer = request.referrer.present? && url_from(request.referrer).nil?
      end

      # Only create a visit if we have some useful data or way of tracking users across pages
      return unless tracking_token || user || has_utm_params || has_external_referrer

      @skadi_visit = Skadi::Visit.build_from(tracking_token, user, request)
    end

    # Called before the action to build the Skadi view model
    def track_view
      @skadi_view = Skadi::View.new

      @skadi_view.view_token = SecureRandom.uuid_v7
      @skadi_view.verified = false

      @skadi_view.controller = controller_name
      @skadi_view.action = action_name
      @skadi_view.verb = request.request_method
      @skadi_view.path = Skadi::Url.view_path_from_request(request)

      @skadi_view.query_params = Skadi::Url.whitelist_query_params(request.query_parameters)
      @skadi_view.referrer = Skadi::Url.redact_and_normalise_url(request.referrer)
    end

    # Saves the visit and view models to the database, if they have been created and tracking is enabled
    def skadi_persist
      return if do_not_track?

      @skadi_visit&.save
      if @skadi_view
        @skadi_view.visit = @skadi_visit
        @skadi_view.save
      end
    end
  end
end

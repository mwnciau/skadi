# Adds Skadi Analytics helper methods to your controller, and enabled automatic tracking if configured.
module Skadi
  module Analytics
    extend ActiveSupport::Concern

    included do
      before_action :track_visit, :track_view

      after_action :skadi_persist

      # Make thse methods available in the view for when we output the frontend script
      helper_method :skadi_visit, :skadi_view

      # Add the Skadi view helper methods
      helper Skadi::ApplicationHelper

      # Disable Skadi tracking for the current controller
      def self.do_not_track!
        skip_before_action :track_visit, :track_view
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
    def do_not_track?
      @skadi_do_not_track
    end

    # Called before the action to find or build the Skadi visit model
    def track_visit
      # If the user has opted out of tracking, we do not use cookies or anonymisation sets
      unless cookies["skadi_tracking_opt_out"] == "1"
        tracking_token = cookies[:skadi_id].presence || AnonymitySet.calculate(request.remote_ip, request.user_agent)
        user = Skadi.configuration.user_method ? send(Skadi.configuration.user_method) : nil

        @skadi_visit = Skadi::Analytics.find_existing_visit(tracking_token, user)

        return if @skadi_visit
      end

      has_utm_params = params.keys.any? { |it| it.to_s.start_with?("utm_") }
      has_external_referrer = request.referer.present? && !request.referer.include?(request.host)

      # Only create a visit if we have some useful data or way of tracking users across pages
      return unless tracking_token || user || has_utm_params || has_external_referrer

      @skadi_visit = Skadi::Analytics.create_visit(tracking_token, user, request)
    end

    # Called before the action to build the Skadi view model
    def track_view
      @skadi_view = Skadi::View.new

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
      @skadi_view&.save
    end

    def self.find_existing_visit(tracking_token, user)
      visit_query = nil
      if tracking_token
        visit_query = Skadi::Visit.where(tracking_token: tracking_token)
          .and(Skadi::Visit.where("created_at > ?", Skadi.configuration.visit_duration.ago))
      end
      if user
        user_visit_query = Skadi::Visit.where(user_id: user.id)
          .and(Skadi::Visit.where("created_at > ?", Skadi.configuration.visit_duration.ago))

        visit_query = visit_query ? visit_query.or(user_visit_query) : user_visit_query
      end

      visit_query&.first
    end

    # @param tracking_token [String]
    # @param user [Object]
    # @param request [ActionDispatch::Request]
    # @return [Skadi::Visit]
    def self.create_visit(tracking_token, user, request)
      visit = Skadi::Visit.new

      visit.tracking_token = tracking_token
      visit.user_id = user&.id

      visit.referrer = Skadi::Url.redact_and_normalise_url(request.referrer)
      visit.landing_page = Skadi::Url.view_path_from_request(request)

      visit.utm_source = request.query_parameters["utm_source"]
      visit.utm_medium = request.query_parameters["utm_medium"]
      visit.utm_term = request.query_parameters["utm_term"]
      visit.utm_content = request.query_parameters["utm_content"]
      visit.utm_campaign = request.query_parameters["utm_campaign"]

      visit
    end
  end
end

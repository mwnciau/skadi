module Skadi
  class ControllerDelegate

    # The controller that instantiated us
    # @return [ActionController::Base]
    attr_reader :controller

    attr_reader :view, :visit, :events, :demographics

    # The parsed user agent
    # @return [Skadi::UserAgent]
    def user_agent = @_user_agent ||= UserAgent.new(request.user_agent || "")

    # Whether the current request has recorded a new visit
    # @return [TrueClass, FalseClass]
    def new_visit? = @new_visit

    # The current request
    # @return [ActionDispatch::Request]
    private def request = controller.request

    # The skadi cookie manager for the current request
    # @return [Skadi::CookieManager]
    private def cookie_manager = @_skadi_cookies ||= Skadi::CookieManager.new(controller.request)

    # @param [ActionController::Base] controller
    def initialize(controller)
      @controller = controller

      @events = []
      @demographics = []

      @do_not_track = Skadi.configuration.do_not_track_bots? && user_agent.bot?
      @new_visit = false
    end

    # Internal. Performs the before-action tasks: build the visit and view, and process user agent
    # info.
    def _prepare
      return if do_not_track?

      build_visit
      build_view
      queue_user_agent_demographics

      cookie_manager.renew!
    end

    # Internal. Saves the visit, view and any events or demographics after the controller action.
    def _persist
      return if do_not_track?

      @visit&.save
      if @view
        @view.visit = @visit
        @view.save
      end

      if @demographics.any?
        Demographic.create_or_increment_all(*@demographics)
      end

      if @events && @events.length > 0
        @events.each do |event|
          if event[:sensitive]
            # Sensitive events should have their created date redacted so they cannot be linked to views/visits based on timings
            event[:created_at] = Time.current.beginning_of_day
          else
            # Attach events to the current visit and view, only if it is not marked as sensitive
            event[:view_id] = @view.id
            event[:visit_id] = @visit&.id
          end

          event.delete(:sensitive)
        end

        Event.insert_all(@events)
      end
    end

    # Whether Skadi tracking has been disabled for the current request
    # @return [Boolean]
    def do_not_track?
      @do_not_track
    end

    # Disable tracking for the current request
    def do_not_track!
      @do_not_track = true
    end

    def demographic(name, value, view_specific = false)
      demographic = {name:, value:}
      demographic[:uri] = request.route_uri_pattern if view_specific

      @demographics << demographic
    end

    def event(name, properties = {}, sensitive: false)
      event = {name:, properties:, sensitive:}

      @events << event
    end

    private def build_visit
      tracking_token, user, has_utm_params, has_external_referrer = nil

      cookie_tracking_token = cookie_manager.tracking_token
      consent = cookie_tracking_token.present?

      # If the user has opted out of tracking, we do not use cookies or anonymity sets
      unless cookie_manager.tracking_opt_out
        tracking_token = cookie_tracking_token || AnonymitySet.calculate(request.remote_ip, request.user_agent)

        # Only track the user if we have consent
        if consent
          user = Skadi.configuration.user_method ? controller.send(Skadi.configuration.user_method) : nil
        end

        @visit = Visit.find_active_visit_for(tracking_token, user)

        # Update the user if the user has logged in since the last view
        @visit.user = user if @visit && @visit.user.nil?

        return if @visit
      end

      unless tracking_token || user
        has_utm_params = request.query_parameters.keys.any? { |it| it.to_s.start_with?("utm_") }
        has_external_referrer = request.referrer.present? && controller.url_from(request.referrer).nil?
      end

      # Only create a visit if we have some useful data or way of tracking users across pages
      return unless tracking_token || user || has_utm_params || has_external_referrer

      @visit = Visit.build_from(tracking_token, user, request)
      @new_visit = true
    end

    private def build_view
      @view = View.new(
        view_token: SecureRandom.uuid_v7,
        verified: false,
        controller: controller.controller_name,
        action: controller.action_name,
        verb: request.request_method,
        path: Url.view_path_from_request(request),
        query_params: Url.whitelist_query_params(request.query_parameters),
        referrer: Url.redact_and_normalise_url(request.referrer),
      )
    end

    private def queue_user_agent_demographics
      # Only track the user agent data when we are recording a new visit so we don't duplicate the data
      return unless new_visit?

      demographic "Browser", user_agent.browser
      demographic "Browser version", "#{user_agent.browser} #{user_agent.browser_version}"
      demographic "Browser engine", user_agent.engine
      demographic "Browser engine version", "#{user_agent.engine} #{user_agent.engine_version}"
      demographic "Operating system", user_agent.os
    end
  end
end

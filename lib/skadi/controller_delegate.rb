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
    def initialize(controller, bot_protection: true)
      @controller = controller

      @events = []
      @demographics = []

      @do_not_track = bot_protection && Skadi.configuration.do_not_track_bots? && user_agent.bot?
      @new_visit = false
    end

    # Internal. Performs the before-action tasks: build the visit and view, and process user agent
    # info.
    def _prepare
      return if do_not_track?

      build_visit
      build_view
      queue_user_agent_demographics
    end

    # Internal. Manually set the view and visit for the current request.
    def _attach(view: nil, visit: nil)
      @visit = visit
      @view = view
    end

    # Internal. Saves the visit, view and any events or demographics after the controller action.
    def _persist
      return if do_not_track?

      @visit&.save
      if @view
        @view.visit = @visit
        @view.save
      end

      if @events.any?
        Skadi::Event.redact_and_insert(@events, visit: @visit, view: @view)
      end

      if @demographics.any?
        Demographic.create_or_increment_all(@demographics)
      end

      cookie_manager.renew!
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error("Skadi: failed to persist analytics for #{controller.controller_name}##{controller.action_name} (visit: #{@visit.try(:id).inspect}, view: #{@view.try(:id).inspect}, events: #{@events.count}, demographics: #{@demographics.count}): #{e.class}, #{e.message}; Line: #{e.backtrace&.first}")

      raise if Rails.env.local?
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

    def consent!
      anonymity_set = @visit&.tracking_token
      tracking_token = ::SecureRandom.uuid_v7

      cookie_manager.tracking_token = tracking_token
      cookie_manager.tracking_opt_out = false

      # Update the existing visit with the tracking token if we've generated a new one
      if @visit
        @visit.tracking_token = tracking_token
      end

      # Update previous visits with the same anonymity set with the new tracking token
      if anonymity_set
        Skadi::Visit.where(tracking_token: anonymity_set).update_all(tracking_token: tracking_token)
      end
    end

    def opt_out!
      cookie_manager.tracking_opt_out = true
      cookie_manager.tracking_token = nil

      if @visit&.tracking_token
        # If an existing tracking token, delete any rows using it so existing data is anonymised instantly
        # Note: this needs a DB update because there may be other visits outside the visit limit
        Skadi::Visit.where(tracking_token: @visit.tracking_token).update_all(tracking_token: nil)

        # Update the local copy so it doesn't get re-set
        @visit.tracking_token = nil
      end

      if @visit&.user&.id
        # If an existing user, delete any rows using it so existing data is anonymised instantly
        # Note: this needs a DB update because there may be other visits outside the visit limit
        Skadi::Visit.where(user_id: @visit.user.id).update_all(user_id: nil)

        # Update the local copy so it doesn't get re-set
        @visit.user = nil
      end
    end

    # Create or increment a demographic with a given name or value. If the action_specific parameter
    # is set to true, the demographic is linked specifically to the current action. Demographics are
    # not linked to any other individual data. E.g:
    #
    #   skadi.demographic("browser", "Chrome")
    #   skadi.demographic("branch", "A", action_specific: true)
    #
    # If the name/value/action combination doesn't exist for the current date, a new row is added to
    # the database with count set to 1. If it does, the existing record's count is incremented.
    #
    # @param [String] name
    # @param [String] value
    # @param [TrueClass, FalseClass] action_specific
    def demographic(name, value, action_specific: false, uri: nil)
      raise ArgumentError.new "Skadi::ControllerDelegate.demographic expects String as first parameter, got #{name.is_a?(String) ? "empty string" : name.class.name}" unless name.is_a?(String) && name.present?
      raise ArgumentError.new "Skadi::ControllerDelegate.demographic expects String as second parameter, got #{value.is_a?(String) ? "empty string" : value.class.name}" unless value.is_a?(String) && value.present?

      demographic = {name:, value:, uri: action_specific ? (uri || request.route_uri_pattern) : nil}

      @demographics << demographic
    end

    # Create an event with the given name and properties. By default, events are linked to the
    # current visit and view, but if the sensitive parameter is set to true, the event is not linked
    # to the visit and view, and the time of the event is set to the start of the current day.
    #
    # @param [String] name
    # @param [Hash] properties
    # @param [TrueClass, FalseClass] sensitive
    def event(name, properties = {}, sensitive: false)
      raise ArgumentError.new "Skadi::ControllerDelegate.event expects String as first parameter, got #{name.is_a?(String) ? "empty string" : name.class.name}" unless name.is_a?(String) && name.present?
      raise ArgumentError.new "Skadi::ControllerDelegate.event expects Hash as second parameter, got #{properties.class.name}" unless properties.is_a?(Hash)

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

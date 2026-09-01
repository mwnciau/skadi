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

      @untracked_bot = bot_protection && Skadi.configuration.do_not_track_bots? && user_agent.bot?
      @do_not_track = false
      @new_visit = false
    end

    # Internal. Performs the before-action tasks: build the visit and view, and process user agent
    # info.
    def _prepare
      return if do_not_track?

      # We queue the bot demographic regardless of if the request is detected as a bot or not
      queue_bot_demographics

      # If this is a bot visit and bot tracking is disabled, do not generate request metrics
      return if untracked_bot?

      build_visit
      build_view
      queue_user_agent_demographics
    rescue => e
      # Analytics must not interfere with the host app's request on failure
      Rails.logger.error("Skadi: failed to prepare analytics for #{controller.controller_name}##{controller.action_name} (visit: #{@visit.try(:id).inspect}, view: #{@view.try(:id).inspect}, events: #{@events.count}, demographics: #{@demographics.count}): #{e.class}, #{e.message}; Line: #{e.backtrace&.first}")

      # Ensure errors are visible in test and development
      raise if Rails.env.local?
    end

    # Internal. Manually set the view and visit for the current request.
    def _attach(view: nil, visit: nil)
      @visit = visit
      @view = view
    end

    # Internal. Saves the visit, view and any events or demographics after the controller action.
    def _persist
      return if do_not_track?

      if untracked_bot?
        # Persist demogaphics so that bot counts are persisted
        Demographic.create_or_increment_all(@demographics) if @demographics.any?

        return
      end

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
    rescue => e
      # Analytics must not interfere with the host app's request on failure
      Rails.logger.error("Skadi: failed to persist analytics for #{controller.controller_name}##{controller.action_name} (visit: #{@visit.try(:id).inspect}, view: #{@view.try(:id).inspect}, events: #{@events.count}, demographics: #{@demographics.count}): #{e.class}, #{e.message}; Line: #{e.backtrace&.first}")

      # Ensure errors are visible in test and development
      raise if Rails.env.local?
    end

    # Whether Skadi tracking has been disabled for the current request
    # @return [Boolean]
    def do_not_track?
      @do_not_track
    end

    # Whether the current request has been detected as a bot and we're not tracking them
    # @return [Boolean]
    def untracked_bot?
      @untracked_bot
    end

    # Disable tracking for the current request
    def do_not_track!
      @do_not_track = true
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
      return if untracked_bot?

      raise ArgumentError.new "Skadi::ControllerDelegate.demographic expects String as first parameter, got #{name.is_a?(String) ? "empty string" : name.class.name}" unless name.is_a?(String) && name.present?
      raise ArgumentError.new "Skadi::ControllerDelegate.demographic expects String as second parameter, got #{value.is_a?(String) ? "empty string" : value.class.name}" unless value.is_a?(String) && value.present?

      demographic = { name:, value:, uri: action_specific ? (uri || request.route_uri_pattern) : nil }

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
      return if untracked_bot?

      raise ArgumentError.new "Skadi::ControllerDelegate.event expects String as first parameter, got #{name.is_a?(String) ? "empty string" : name.class.name}" unless name.is_a?(String) && name.present?
      raise ArgumentError.new "Skadi::ControllerDelegate.event expects Hash as second parameter, got #{properties.class.name}" unless properties.is_a?(Hash)

      event = { name:, properties:, sensitive: }

      @events << event
    end

    # Set consent for tracking by anonymity set
    # @param [TrueClass, FalseClass] consent
    def anonymity_set_consent!(consent)
      anonymity_set = AnonymitySet.calculate(request.remote_ip, request.user_agent)

      if consent
        cookie_manager.use_anonymity_sets = true

        # If a visit is attached to the request, we update it with the anonymity set token
        if @visit
          @visit.tracking_token ||= anonymity_set
        else
          # Build the visit without the request, because the current request is likely not the original first request
          @visit = Visit.build_from(anonymity_set)
          @view.visit = @visit if @view
        end
      else
        cookie_manager.use_anonymity_sets = false

        return if @visit.nil?

        # Check to see if the currrent visit is using an anonymity set
        if @visit&.tracking_token && !@visit.cookies_enabled
          # If so, delete it from the db so existing data is anonymised instantly
          # Note: this needs to be a DB update because there may be other visits outside the visit limit
          Skadi::Visit.where(tracking_token: anonymity_set).update_all(tracking_token: nil)

          # Update the local instance of the visit if it uses anonymity sets so it doesn't get re-set when saved
          @visit.tracking_token = nil if @visit.tracking_token == anonymity_set
        end
      end
    end

    def anonymity_set_consent?
      cookie_value = cookie_manager.use_anonymity_sets
      return cookie_value unless cookie_value.nil?

      # There is no explicit consent or opt-out, so we use the configured default value
      return Skadi.configuration.use_anonymity_sets
    end

    # Set consent for tracking by cookie
    # @param [TrueClass, FalseClass] consent
    def cookie_consent!(consent)
      if consent
        return unless cookie_manager.tracking_token.nil?

        # Re-use an existing cookie-based token
        tracking_token = @visit&.tracking_token if @visit&.cookies_enabled
        tracking_token ||= ::SecureRandom.uuid_v7

        cookie_manager.tracking_token = tracking_token

        # Update the existing visit with the tracking token if we've generated a new one
        if @visit
          @visit.tracking_token = tracking_token
          @visit.cookies_enabled = true
        else
          @visit = Visit.build_from(tracking_token, cookies_enabled: true)
          @view.visit = @visit if @view
        end
      else
        cookie_manager.tracking_token = nil

        return if @visit.nil?

        # No need to anonymise existing sessions here because there is no way to link to the user once the tracking token is deleted.
        @visit.cookies_enabled = false

        # If the user has opted in for anonymity sets
        if cookie_manager.use_anonymity_sets == true || (Skadi.configuration.use_anonymity_sets && cookie_manager.use_anonymity_sets != false)
          @visit.tracking_token = AnonymitySet.calculate(request.remote_ip, request.user_agent)
        end
      end
    end

    def cookie_consent? = cookie_manager.tracking_token.present?

    # Set consent for tracking by logged in user
    # @param [TrueClass, FalseClass] consent
    def user_consent!(consent)
      tracked_user_id = @visit&.user_id || logged_in_user&.id

      if consent
        cookie_manager.track_users = true

        unless tracked_user_id.nil?
          if @visit
            @visit.user_id = tracked_user_id
          else
            # Build the visit without the request, because the current request is likely not the original first request
            @visit = Visit.build_from(nil, tracked_user_id)
            @view.visit = @visit if @view
          end
        end
      else
        cookie_manager.track_users = false

        # If there is a logged in user, we delete the user id from any rows that match
        unless tracked_user_id.nil?
          # Note: this needs a DB update because there may be other visits outside the visit limit
          Skadi::Visit.where(user_id: tracked_user_id).update_all(user_id: nil)

          # Update the local instance of the current visit so it doesn't get re-set when saved
          @visit.user_id = nil if @visit
        end
      end
    end

    def user_consent?
      cookie_value = cookie_manager.track_users
      return cookie_value unless cookie_value.nil?

      # There is no explicit consent or opt-out, so we use the configured default value
      return Skadi.configuration.track_users
    end

    private def build_visit
      user, has_utm_params, has_external_referrer = nil

      tracking_token = cookie_manager.tracking_token

      if tracking_token.nil? && anonymity_set_consent?
        tracking_token = AnonymitySet.calculate(request.remote_ip, request.user_agent)
      end

      if user_consent?
        user = logged_in_user
      end

      @visit = Visit.find_active_visit_for(tracking_token, user)

      if @visit
        # Update the user if the user has logged in since the last view
        @visit.user_id = user.id if user && @visit.user_id.nil?

        # Ensure the cookie consent status is up to date
        @visit.cookies_enabled = cookie_consent?

        return
      end

      unless tracking_token || user
        has_utm_params = request.query_parameters.keys.any? { |it| it.to_s.start_with?("utm_") }
        has_external_referrer = request.referrer.present? && controller.url_from(request.referrer).nil?
      end

      # Only create a visit if we have some useful data or way of tracking users across pages
      return unless tracking_token || user || has_utm_params || has_external_referrer

      @visit = Visit.build_from(tracking_token, user&.id, request)
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

    private def queue_bot_demographics
      return unless Skadi.configuration.count_bots

      # We manually queue it to avoid the `untracked_bot?` early return of #demographic
      @demographics << { name: "Traffic type", value: user_agent.bot? ? "Bot" : "Human", uri: request.route_uri_pattern }
    end

    private def logged_in_user
      return @logged_in_user if defined?(@logged_in_user)

      return nil if Skadi.configuration.user_controller_method.nil?
      return nil unless controller.respond_to?(Skadi.configuration.user_controller_method, true)

      @logged_in_user = controller.send(Skadi.configuration.user_controller_method)

      return @logged_in_user
    end
  end
end

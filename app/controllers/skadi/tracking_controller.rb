module Skadi
  class TrackingController < ActionController::API
    include ActionController::Cookies

    # Disables the automatic wrapping of JSON parameters into a "tracking" hash
    wrap_parameters false

    prepend_before_action :limit_payload_size!

    rate_limit to: 60, within: 1.minute, with: -> { head :too_many_requests }

    before_action :set_params
    before_action :set_view

    def track
      if @params["exit_page"].present? && @params["exit_page"].is_a?(String)
        @view.exit_page = Skadi::Url.redact_and_normalise_url(@params["exit_page"])
      end

      handle_consent @params["consent"]

      if @params["events"].present? && @params["events"].is_a?(Array)
        handle_events @params["events"]
      end

      if @params["demographics"].present? && @params["demographics"].is_a?(Array)
        handle_demographics @params["demographics"]
      end

      @view.verified = true
      @view.save

      if @view.visit
        @view.visit.verified = true
        @view.visit.save
      end

      head :no_content
    end

    private def set_params
      @params = request.request_parameters
    end

    private def set_view
      # Check that the view token is a valid UUID
      unless @params["view"].is_a?(String) && @params["view"].length == 36
        return head :bad_request
      end

      @view = Skadi::View.includes(:visit).find_by(view_token: @params["view"])

      return head :not_found unless @view

      head :gone unless @view.created_at > Time.current - Skadi.configuration.visit_duration
    end

    private def handle_consent(consent)
      if consent == true
        tracking_token = @view.visit&.tracking_token || ::SecureRandom.uuid_v7

        cookie_manager.tracking_token = tracking_token
        cookie_manager.tracking_opt_out = false

        # Update the existing visit with the tracking token if we've generated a new one
        if @view.visit
          @view.visit.tracking_token = tracking_token
        end
      elsif consent == false
        cookie_manager.tracking_opt_out = true
        cookie_manager.tracking_token = nil

        if @view.visit&.tracking_token
          # If an existing tracking token, delete any rows using it so existing data is anonymised instantly
          # Note: this needs a DB update because there may be other visits outside the visit limit
          Skadi::Visit.where(tracking_token: @view.visit.tracking_token).update_all(tracking_token: nil)

          # Update the local copy so it doesn't get re-set
          @view.visit.tracking_token = nil
        end

        if @view.visit&.user&.id
          # If an existing user, delete any rows using it so existing data is anonymised instantly
          # Note: this needs a DB update because there may be other visits outside the visit limit
          Skadi::Visit.where(user_id: @view.visit.user.id).update_all(user_id: nil)

          # Update the local copy so it doesn't get re-set
          @view.visit.user = nil
        end
      end
    end

    private def cookie_manager = @_skadi_cookies ||= Skadi::CookieManager.new(request)

    private def handle_events(events)
      events_to_insert = []

      events.each do |event|
        next unless event.is_a?(Hash)
        next unless event["name"].is_a?(String) && event["name"].present?
        next unless event["properties"].is_a?(Hash)

        events_to_insert << {visit: @view.visit, name: event["name"].strip[0, 255], properties: event["properties"]}
      end

      return if events_to_insert.empty?

      @view.events.create(events_to_insert)
    end

    private def handle_demographics(demographics)
      demographics_to_update = []

      demographics.each do |demographic|
        next unless demographic.is_a?(Hash)
        next unless demographic["name"].is_a?(String) && demographic["name"].present?
        next unless demographic["value"].is_a?(String) && demographic["value"].present?
        next unless demographic["uri"].nil? || demographic["uri"].is_a?(String)

        demographics_to_update << {
          name: demographic["name"],
          value: demographic["value"],
          uri: demographic["uri"],
        }
      end

      return if demographics_to_update.empty?

      Skadi::Demographic.create_or_increment_all(*demographics_to_update)
    end

    def limit_payload_size!
      if request.content_length && request.content_length > Skadi.configuration.max_tracking_payload_size
        render json: {error: "Payload too large"}, status: :content_too_large
      end
    end
  end
end

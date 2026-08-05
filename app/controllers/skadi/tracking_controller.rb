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
      @view.visit.verified = true if @view.visit

      skadi._persist

      head :no_content
    end

    private def skadi
      # Disable bot protection, since that will have been done when the visit/view was created
      @_skadi ||= Skadi::ControllerDelegate.new(self, bot_protection: false)
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

      return head :gone unless @view.created_at > Time.current - Skadi.configuration.visit_duration

      # We're not using _prepare to generate the view/visit, so we have to set them manually
      skadi._attach(view: @view, visit: @view.visit)
    end

    private def handle_consent(consent)
      return unless consent.is_a?(Hash)

      if consent["cookie"] == true || consent["cookie"] == false
        skadi.cookie_consent!(consent["cookie"])
      end

      if consent["anonymity_set"] == true || consent["anonymity_set"] == false
        skadi.anonymity_set_consent!(consent["anonymity_set"])
      end

      if consent["user"] == true || consent["user"] == false
        skadi.user_consent!(consent["user"])
      end
    end

    private def handle_events(events)
      events.each do |event|
        next unless event.is_a?(Hash)
        next unless event["name"].is_a?(String) && event["name"].present?
        next unless event["properties"].is_a?(Hash)

        skadi.event(event["name"], event["properties"])
      end
    end

    private def handle_demographics(demographics)
      demographics.each do |demographic|
        next unless demographic.is_a?(Hash)
        next unless demographic["name"].is_a?(String) && demographic["name"].present?
        next unless demographic["value"].is_a?(String) && demographic["value"].present?
        next unless demographic["uri"].nil? || demographic["uri"].is_a?(String)

        skadi.demographic(demographic["name"], demographic["value"], action_specific: true, uri: demographic["uri"] || "")
      end
    end

    def limit_payload_size!
      if request.content_length && request.content_length > Skadi.configuration.max_tracking_payload_size
        render json: { error: "Payload too large" }, status: :content_too_large
      end
    end
  end
end

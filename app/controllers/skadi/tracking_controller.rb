module Skadi
  class TrackingController < ActionController::API
    include ActionController::Cookies

    # Disables the automatic wrapping of JSON parameters into a "tracking" hash
    wrap_parameters false

    prepend_before_action :limit_payload_size!

    before_action :set_params
    before_action :set_view

    def track
      if @params["exit_page"].present? && @params["exit_page"].is_a?(String)
        @view.exit_page = @params["exit_page"]
      end

      if @params["consent"].is_a? Hash
        handle_consent @params["consent"]
      end

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
        @view.changed?
      end

      head :no_content
    end

    private

    def set_params
      @params = request.request_parameters
    end

    def set_view
      unless @params["view"]
        return head :bad_request
      end

      @view = Skadi::View.includes(:visit).find_by(view_token: @params["view"])

      return head :not_found unless @view

      head :gone unless @view.created_at > Time.current - Skadi.configuration.visit_duration
    end

    private def handle_consent(consent)
      if consent["opt_out"]
        set_cookie "skadi_tracking_opt_out", "1"

        # If an existing visit exists, update it with a random tracking token to anonymise the user immediately
        if @view.visit
          @view.visit.tracking_token = ::SecureRandom.uuid_v7
        end
      elsif consent["opt_out"] == false
        clear_cookie "skadi_tracking_opt_out"
      end

      if consent["id"]
        set_cookie("skadi_id", @view.visit&.tracking_token || ::SecureRandom.uuid_v7)
      elsif consent["id"] == false
        clear_cookie "skadi_id"
      end
    end

    private def handle_events(events)
      events_to_insert = []

      events.each do |event|
        next unless event.is_a?(Hash)
        next unless event["name"].is_a?(String) && event["name"].present?
        next unless event["properties"].is_a?(Hash)

        events_to_insert << {visit: @view.visit, name: event["name"], properties: event["properties"]}
      end

      @view.events.create(events_to_insert)
    end

    private def handle_demographics(demographics)
      demographics_to_insert = []

      demographics.each do |demographic|
        next unless demographic.is_a?(Hash)
        next unless demographic["name"].is_a?(String) && demographic["name"].present?
        next unless demographic["value"].is_a?(String) && demographic["value"].present?
        next unless demographic["uri"].nil? || demographic["uri"].is_a?(String)

        demographics_to_insert << {
          name: demographic["name"],
          value: demographic["value"],
          # SQL specifies NULL values are not equal, so we need to default the URI to an empty string
          # to ensure the unique index works correctly
          uri: demographic["uri"] || "",
          recorded_on: Time.now,
          count: 1,
        }
      end

      Skadi::Demographic.upsert_all(
        demographics_to_insert,
        unique_by: [:uri, :name, :value, :recorded_on],
        on_duplicate: Arel.sql("count = skadi_demographics.count + 1"),
        returning: false,
      )
    end

    def set_cookie(name, value, age = 31536000)
      cookies[name] = {
        value:,
        domain: Skadi.configuration.cookie_domain,
        httponly: true,
        secure: request.ssl?,
        same_site: :lax,
        expires: age.seconds.from_now
      }
    end

    def clear_cookie(name)
      cookies.delete(name, domain: Skadi.configuration.cookie_domain)
    end

    def limit_payload_size!
      if request.content_length && request.content_length > Skadi.configuration.max_tracking_payload_size
        render json: {error: "Payload too large"}, status: :content_too_large
      end
    end
  end
end

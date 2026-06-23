module Skadi
  class CookieManager
    OPT_OUT_KEY = "skadi_tracking_opt_out"
    TRACKING_TOKEN_KEY = "skadi_id"
    UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

    # @return [ActionDispatch::Cookies::CookieJar]
    attr_reader :cookies, :request

    def initialize(request)
      @request = request
      @cookies = request.cookie_jar
    end

    def renew!
      set_cookie OPT_OUT_KEY, "1" if cookies.has_key? OPT_OUT_KEY
      set_cookie TRACKING_TOKEN_KEY, cookies[TRACKING_TOKEN_KEY] if cookies.has_key? TRACKING_TOKEN_KEY
    end

    def tracking_opt_out = cookies[OPT_OUT_KEY] == "1"

    def tracking_opt_out=(new_value)
      if !new_value
        delete_cookie(OPT_OUT_KEY)

        return
      end

      set_cookie OPT_OUT_KEY, "1"
    end

    def tracking_token
      token = cookies[TRACKING_TOKEN_KEY]

      # The cookie is user input, so we ensure the cookie is a UUID as expected
      token&.match(UUID_REGEX) ? token : nil
    end

    def tracking_token=(new_value)
      if new_value.nil?
        delete_cookie(TRACKING_TOKEN_KEY)

        return
      end

      set_cookie TRACKING_TOKEN_KEY, new_value
    end

    private def set_cookie(name, value)
      cookies[name] = {
        value:,
        domain: Skadi.configuration.cookie_domain,
        httponly: true,
        secure: Rails.env.production? || request.ssl?,
        same_site: :lax,
        expires: 1.year.from_now,
      }
    end

    private def delete_cookie(name)
      cookies.delete(name, domain: Skadi.configuration.cookie_domain)
    end
  end
end

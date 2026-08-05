module Skadi
  class CookieManager
    ANONYMITY_SET_KEY = "skadi_anonymity_set"
    TRACKING_TOKEN_KEY = "skadi_id"
    TRACK_USER_KEY = "skadi_track_user"
    UUID_REGEX = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

    # @return [ActionDispatch::Cookies::CookieJar]
    attr_reader :cookies, :request

    def initialize(request)
      @request = request
      @cookies = request.cookie_jar
    end

    def renew!
      set_cookie ANONYMITY_SET_KEY, cookies[ANONYMITY_SET_KEY] if [ "1", "0" ].include?(cookies[ANONYMITY_SET_KEY])
      set_cookie TRACK_USER_KEY, cookies[TRACK_USER_KEY] if [ "1", "0" ].include?(cookies[TRACK_USER_KEY])

      if cookies.has_key? TRACKING_TOKEN_KEY
        token = tracking_token
        if token
          set_cookie TRACKING_TOKEN_KEY, token
        else
          # If the key is set, but the token returned by `tracking_token()` is nil, then the cookie is malformed and we delete it
          delete_cookie TRACKING_TOKEN_KEY
        end
      end
    end

    def use_anonymity_sets
      return true if cookies[ANONYMITY_SET_KEY] == "1"
      return false if cookies[ANONYMITY_SET_KEY] == "0"
    end

    def use_anonymity_sets=(new_value)
      set_cookie ANONYMITY_SET_KEY, new_value ? "1" : "0"
    end

    def track_users
      return true if cookies[TRACK_USER_KEY] == "1"
      return false if cookies[TRACK_USER_KEY] == "0"
    end

    def track_users=(new_value)
      set_cookie TRACK_USER_KEY, new_value ? "1" : "0"
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

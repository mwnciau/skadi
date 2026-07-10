require_relative "test_case"

module Skadi::Unit
  class CookieManagerTest < TestCase
    TRACKING_TOKEN = "8cec5a7a-7bf7-403f-b15e-b2e45944182c"

    test "tracking_token returns the cookie value when it is a valid UUID" do
      manager = build_manager(skadi_id: TRACKING_TOKEN)

      assert_equal TRACKING_TOKEN, manager.tracking_token
    end

    test "tracking_token rejects non-UUID values" do
      manager = build_manager(skadi_id: "not-a-uuid")

      assert_nil manager.tracking_token
    end

    test "tracking_token rejects almost-UUID values" do
      # One character too short, otherwise valid hex
      manager = build_manager(skadi_id: "8cec5a7a-7bf7-403f-b15e-b2e4594418")

      assert_nil manager.tracking_token
    end

    test "tracking_token returns nil when cookie is absent" do
      manager = build_manager

      assert_nil manager.tracking_token
    end

    test "tracking_token= writes the cookie" do
      request = build_request
      manager = Skadi::CookieManager.new(request)

      manager.tracking_token = TRACKING_TOKEN

      assert_equal TRACKING_TOKEN, request.cookie_jar["skadi_id"]
    end

    test "tracking_token= with nil deletes the cookie" do
      request = build_request({skadi_id: TRACKING_TOKEN})
      manager = Skadi::CookieManager.new(request)

      manager.tracking_token = nil

      assert_nil request.cookie_jar["skadi_id"]
    end

    test "use_anonymity_sets is true when cookie is '1'" do
      manager = build_manager(skadi_anonymity_set: "1")

      assert manager.use_anonymity_sets == true
    end

    test "use_anonymity_sets is false when cookie is '0'" do
      manager = build_manager(skadi_anonymity_set: "0")

      assert manager.use_anonymity_sets == false
    end

    test "use_anonymity_sets is nil when cookie is not set" do
      manager = build_manager

      assert manager.use_anonymity_sets.nil?
    end

    test "use_anonymity_sets is nil when cookie is invalid" do
      manager = build_manager(skadi_anonymity_set: "invalid")

      assert manager.use_anonymity_sets.nil?
    end

    test "use_anonymity_sets= true sets cookie to '1'" do
      request = build_request
      manager = Skadi::CookieManager.new(request)

      manager.use_anonymity_sets = true

      assert_equal "1", request.cookie_jar["skadi_anonymity_set"]
    end

    test "use_anonymity_sets= false sets the cookie to 0" do
      request = build_request({skadi_anonymity_set: "1"})
      manager = Skadi::CookieManager.new(request)

      manager.use_anonymity_sets = false

      assert_equal "0", request.cookie_jar["skadi_anonymity_set"]
    end

    test "track_users is true when cookie is '1'" do
      manager = build_manager(skadi_track_user: "1")

      assert manager.track_users == true
    end

    test "track_users is false when cookie is '0'" do
      manager = build_manager(skadi_track_user: "0")

      assert manager.track_users == false
    end

    test "track_users is nil when cookie is not set" do
      manager = build_manager

      assert manager.track_users.nil?
    end

    test "track_users is nil when cookie is invalid" do
      manager = build_manager(skadi_track_user: "invalid")

      assert manager.track_users.nil?
    end

    test "track_users= true sets cookie to '1'" do
      request = build_request
      manager = Skadi::CookieManager.new(request)

      manager.track_users = true

      assert_equal "1", request.cookie_jar["skadi_track_user"]
    end

    test "track_users= false sets the cookie to 0" do
      request = build_request({skadi_track_user: "1"})
      manager = Skadi::CookieManager.new(request)

      manager.track_users = false

      assert_equal "0", request.cookie_jar["skadi_track_user"]
    end

    test "renew! re-writes existing cookies" do
      request = build_request({skadi_id: TRACKING_TOKEN, skadi_anonymity_set: "1", skadi_track_user: "1"})
      manager = Skadi::CookieManager.new(request)

      manager.renew!

      # The cookies are still present, and the underlying jar has new write options
      assert_equal TRACKING_TOKEN, request.cookie_jar["skadi_id"]
      assert_equal "1", request.cookie_jar["skadi_anonymity_set"]
      assert_equal "1", request.cookie_jar["skadi_track_user"]
    end

    test "renew! does not create cookies that do not exist" do
      request = build_request
      manager = Skadi::CookieManager.new(request)

      manager.renew!

      assert_nil request.cookie_jar["skadi_id"]
      assert_nil request.cookie_jar["skadi_anonymity_set"]
      assert_nil request.cookie_jar["skadi_track_user"]
    end

    test "renew! deletes tracking token for invalid skadi_id cookie" do
      request = build_request({skadi_id: "invalid tracking token"})
      manager = Skadi::CookieManager.new(request)

      manager.renew!

      assert_nil request.cookie_jar["skadi_id"]
    end

    test "cookies set in production are secure" do
      Rails.env = "production"
      request = build_request

      Skadi::CookieManager.new(request).tracking_token = TRACKING_TOKEN

      cookie = cookie_options(request, "skadi_id")
      assert cookie[:secure], "Expected the tracking cookie to be secure in production"
    ensure
      Rails.env = "test"
    end

    test "cookies are not secure in non-production over plain HTTP" do
      request = build_request

      Skadi::CookieManager.new(request).tracking_token = TRACKING_TOKEN

      cookie = cookie_options(request, "skadi_id")
      refute cookie[:secure]
    end

    test "cookies set over SSL are secure regardless of environment" do
      request = build_request(ssl: true)

      Skadi::CookieManager.new(request).tracking_token = TRACKING_TOKEN

      cookie = cookie_options(request, "skadi_id")
      assert cookie[:secure]
    end

    test "cookies are httponly, lax, and expire in a year" do
      request = build_request

      Skadi::CookieManager.new(request).tracking_token = TRACKING_TOKEN

      cookie = cookie_options(request, "skadi_id")
      assert cookie[:httponly]
      assert_equal :lax, cookie[:same_site]
      assert_in_delta 1.year.from_now.to_i, cookie[:expires].to_i, 5
    end

    private def build_manager(cookies = {})
      Skadi::CookieManager.new(build_request(cookies))
    end

    private def build_request(cookies = {}, ssl: false)
      env = Rack::MockRequest.env_for("/", "HTTP_HOST" => "example.com")
      env["HTTPS"] = "on" if ssl
      env["HTTP_COOKIE"] = cookies.map { |k, v| "#{k}=#{v}" }.join("; ") unless cookies.empty?

      ActionDispatch::Request.new(env)
    end

    # Look up the options hash that the jar recorded for a written cookie
    private def cookie_options(request, name)
      request.cookie_jar.instance_variable_get(:@set_cookies)[name.to_s]
    end
  end
end

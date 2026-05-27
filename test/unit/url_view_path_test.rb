require_relative "test_case"

module Skadi::Unit
  class UrlViewPathTest < TestCase
    test "view path from request" do
      request = build_request("https://example.com/foo/bar")

      assert_equal "/foo/bar", Skadi::Url.view_path_from_request(request)
    end

    test "view path trailing slashes are normalised" do
      request_1 = build_request("https://example.com/foo/bar")
      request_2 = build_request("https://example.com/foo/bar/")

      assert_equal "/foo/bar", Skadi::Url.view_path_from_request(request_1)
      assert_equal "/foo/bar", Skadi::Url.view_path_from_request(request_2)
    end

    test "view path root trailing slashes is preserved" do
      request = build_request("https://example.com/")

      assert_equal "/", Skadi::Url.view_path_from_request(request)
    end

    test "view path includes domain when configured" do
      Skadi.configuration.store_domain_in_views = true

      request = build_request("https://example.com/foo/bar")

      assert_equal "example.com/foo/bar", Skadi::Url.view_path_from_request(request)
    end

    test "view path includes domain and port when non-standard" do
      Skadi.configuration.store_domain_in_views = true

      request = build_request("https://example.com:3000/foo/bar")

      assert_equal "example.com:3000/foo/bar", Skadi::Url.view_path_from_request(request)
    end

    test "view path does not contain standard ports" do
      Skadi.configuration.store_domain_in_views = true

      request_80 = build_request("http://example.com:80/foo/bar")
      request_443 = build_request("https://example.com:443/foo/bar")

      assert_equal "example.com/foo/bar", Skadi::Url.view_path_from_request(request_80)
      assert_equal "example.com/foo/bar", Skadi::Url.view_path_from_request(request_443)
    end

    private def build_request(url)
      ActionDispatch::Request.new(Rack::MockRequest.env_for(url))
    end
  end
end
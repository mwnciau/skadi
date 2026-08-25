require_relative "test_case"

module Skadi::Unit
  class UrlRedactAndNormaliseTest < TestCase
    test "redact_and_normalise_url returns url with no query params" do
      url = Skadi::Url.redact_and_normalise_url("https://example.com/foo/bar/baz")

      assert_equal "example.com/foo/bar/baz", url
    end

    test "redact_and_normalise_url filters query parameters" do
      url = Skadi::Url.redact_and_normalise_url("https://example.com/path?foo=bar&baz=qux")

      assert_equal "example.com/path", url
    end

    test "redact_and_normalise_url removes trailing slash" do
      url_1 = Skadi::Url.redact_and_normalise_url("https://example.com/path/")
      url_2 = Skadi::Url.redact_and_normalise_url("https://example.com/path")

      assert_equal "example.com/path", url_1
      assert_equal "example.com/path", url_2
    end

    test "redact_and_normalise_url keeps slash after host" do
      url_1 = Skadi::Url.redact_and_normalise_url("https://example.com/")
      url_2 = Skadi::Url.redact_and_normalise_url("https://example.com")

      assert_equal "example.com/", url_1
      assert_equal "example.com/", url_2
    end

    test "redact_and_normalise_url strips standard port" do
      http_url = Skadi::Url.redact_and_normalise_url("http://example.com:80")
      https_url = Skadi::Url.redact_and_normalise_url("https://example.com:443")

      assert_equal "example.com/", http_url
      assert_equal "example.com/", https_url
    end

    test "redact_and_normalise_url keeps non-standard port" do
      url = Skadi::Url.redact_and_normalise_url("http://example.com:3000")

      assert_equal "example.com:3000/", url
    end

    test "redact_and_normalise_url strips uri fragment" do
      url = Skadi::Url.redact_and_normalise_url("http://example.com/#url-fragment")

      assert_equal "example.com/", url
    end

    test "redact_and_normalise_url returns nil for invalid URLs" do
      invalid_urls = [
        "not a valid url",
        "ht!tp://bad",
        "",
        nil,
        "   ",
        # Raises a Rack::QueryParser::ParameterTypeError
        "http://example.com/?a=1&a[b]=2",
      ]

      invalid_urls.each do |url|
        assert_nil Skadi::Url.redact_and_normalise_url(url)
      end
    end

    test "redact_and_normalise_url truncates URLs to configured length" do
      Skadi.configuration.max_url_length = 2048
      url_2048 = Skadi::Url.redact_and_normalise_url("http://example.com/" + ("a" * 2048))

      Skadi.configuration.max_url_length = 4096
      url_4096 = Skadi::Url.redact_and_normalise_url("http://example.com/" + ("a" * 4096))

      # 7 characters shorter due to the scheme being removed
      assert_equal 2041, url_2048.length
      assert_equal 4089, url_4096.length
    end

    test "redact_and_normalise_url truncation doesn't break url parsing" do
      Skadi.configuration.max_url_length = 24

      # Truncates to "http://example.com/?abc["
      url = Skadi::Url.redact_and_normalise_url("http://example.com/?abc[]=123")

      assert_equal "example.com/", url
    end

    test "redact_and_normalise_url only keeps whitelisted params" do
      Skadi.configuration.query_param_whitelist = [ :foo ]

      url = Skadi::Url.redact_and_normalise_url("http://example.com/?foo=bar&baz=qux")

      assert_equal "example.com/?foo=bar", url
    end

    test "redact_and_normalise_url allows all params when whitelist disabled" do
      Skadi.configuration.use_query_param_whitelist = false

      url = Skadi::Url.redact_and_normalise_url("http://example.com/?baz=qux&foo=bar")

      assert_equal "example.com/?baz=qux&foo=bar", url
    end

    test "redact_and_normalise_url handles encoded characters" do
      Skadi.configuration.query_param_whitelist = [ :foo ]

      url = Skadi::Url.redact_and_normalise_url("http://example.com/path%20with%20spaces?foo=param+with+spaces")

      assert_equal "example.com/path%20with%20spaces?foo=param+with+spaces", url
    end

    test "redact_and_normalise_url handles relative urls" do
      url = Skadi::Url.redact_and_normalise_url("/foo?bar=baz")

      assert_equal "/foo", url
    end

    test "redact_and_normalise_url handles protocol-relative urls" do
      url = Skadi::Url.redact_and_normalise_url("//example.com")

      assert_equal "example.com/", url
    end

    test "redact_and_normalise_url handles javascript urls" do
      url = Skadi::Url.redact_and_normalise_url("javascript:alert(1)")

      assert_nil url
    end

    test "redact_and_normalise_url handles data urls" do
      url = Skadi::Url.redact_and_normalise_url("data:text/html,%3Ch1%3EHello%2C%20World%21%3C%2Fh1%3E")

      assert_nil url
    end

    test "redact_and_normalise_url handles interesting schemas" do
      url = Skadi::Url.redact_and_normalise_url("chrome-extension://aggiodmmpapjpafbkppkkcchmlbgciia/popup.html")

      assert_equal "chrome-extension://aggiodmmpapjpafbkppkkcchmlbgciia/popup.html", url
    end

    test "redact_and_normalise_url excludes domain from local urls" do
      request = build_request("https://example.com/current")

      url = Skadi::Url.redact_and_normalise_url("https://example.com/foo/bar", request: request)

      assert_equal "/foo/bar", url
    end

    test "redact_and_normalise_url keeps domain for external urls" do
      request = build_request("https://example.com/current")

      url = Skadi::Url.redact_and_normalise_url("https://other.com/foo/bar", request: request)

      assert_equal "other.com/foo/bar", url
    end

    test "redact_and_normalise_url keeps domain for non-standard requests" do
      request = build_request("https://example.com/current")

      url = Skadi::Url.redact_and_normalise_url("ftp://example.com/foo/bar", request: request)

      assert_equal "ftp://example.com/foo/bar", url
    end

    test "redact_and_normalise_url keeps domain for local urls when store_domain_in_views is set" do
      Skadi.configuration.store_domain_in_views = true

      request = build_request("https://example.com/current")

      url = Skadi::Url.redact_and_normalise_url("https://example.com/foo/bar", request: request)

      assert_equal "example.com/foo/bar", url
    end

    test "redact_and_normalise_url matches local urls with non-standard ports" do
      request = build_request("https://example.com:3000/current")

      local = Skadi::Url.redact_and_normalise_url("https://example.com:3000/foo/bar", request: request)
      external = Skadi::Url.redact_and_normalise_url("https://example.com/foo/bar", request: request)

      assert_equal "/foo/bar", local
      assert_equal "example.com/foo/bar", external
    end

    private def build_request(url)
      ActionDispatch::Request.new(Rack::MockRequest.env_for(url))
    end
  end
end

require_relative "test_case"

module Skadi::Unit
  class UrlWhitelistingQueryParamsTest < TestCase
    test "whitelist_query_params returns empty hash if whitelist is empty" do
      params = {"foo" => "bar", "baz" => "qux"}

      assert_equal({}, Skadi::Url.whitelist_query_params(params))
    end

    test "whitelist_query_params returns empty hash if no keys match" do
      Skadi.configuration.query_param_whitelist = [:fred, :thud]

      params = {"foo" => "bar", "baz" => "qux"}

      assert_equal({}, Skadi::Url.whitelist_query_params(params))
    end

    test "whitelist_query_params only allows whitelisted params" do
      Skadi.configuration.query_param_whitelist = [:foo]

      params = {"foo" => "bar", "baz" => "qux"}

      assert_equal({foo: "bar"}, Skadi::Url.whitelist_query_params(params))
    end

    test "whitelist_query_params handles empty hash" do
      assert_equal({}, Skadi::Url.whitelist_query_params({}))
    end

    test "whitelist_query_params filters hash with string and symbol keys" do
      Skadi.configuration.query_param_whitelist = [:foo, :baz]

      params = {"foo" => "bar", :baz => "qux", "bar" => "foo", :qux => "baz"}

      assert_equal({foo: "bar", baz: "qux"}, Skadi::Url.whitelist_query_params(params))
    end

    test "whitelist_query_params filters HashWithIndifferentAccess with string and symbol keys" do
      Skadi.configuration.query_param_whitelist = [:foo, :baz]

      params = HashWithIndifferentAccess.new({"foo" => "bar", :baz => "qux", "bar" => "foo", :qux => "baz"})

      assert_equal({foo: "bar", baz: "qux"}, Skadi::Url.whitelist_query_params(params))
    end

    test "whitelist_query_params returns input if use_query_param_whitelist is false" do
      Skadi.configuration.use_query_param_whitelist = false
      Skadi.configuration.query_param_whitelist = [:foo]

      params = {foo: "bar", baz: "qux"}

      assert_equal(params, Skadi::Url.whitelist_query_params(params))
    end
  end
end

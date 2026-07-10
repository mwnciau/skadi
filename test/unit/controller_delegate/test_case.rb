require_relative "../test_case"

module Skadi::Unit
  module ControllerDelegate
    class TestCase < ::Skadi::Unit::TestCase
      attr_reader :skadi

      setup do
        @request = ActionDispatch::TestRequest.create
        @controller = ActionController::Base.new
        @controller.request = @request
        @skadi = Skadi::ControllerDelegate.new(@controller)
      end

      private def assert_cookie(name, value)
        cookies = @controller.send(:cookies)

        assert cookies.has_key?(name), "Expected cookie #{name.inspect} to be set" unless value.nil?

        if value.nil?
          assert_nil cookies[name]
        elsif value.is_a?(Regexp)
          assert_match value, cookies[name]
        else
          assert_equal value, cookies[name]
        end
      end

      private def anonymity_set
        @anonymity_set ||= Skadi::AnonymitySet.calculate(@request.remote_ip, @request.user_agent)
      end
    end
  end
end

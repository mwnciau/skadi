require_relative "test_case"

module Skadi::Unit
  module ControllerDelegate
    class ControllerDelegateTest < TestCase
      test "demographic with invalid name" do
        error = assert_raises ArgumentError do
          skadi.demographic(nil, "value")
        end

        assert_equal "Skadi::ControllerDelegate.demographic expects String as first parameter, got NilClass", error.message
      end

      test "demographic with invalid value" do
        error = assert_raises ArgumentError do
          skadi.demographic("name", nil)
        end

        assert_equal "Skadi::ControllerDelegate.demographic expects String as second parameter, got NilClass", error.message
      end

      test "event with invalid name" do
        error = assert_raises ArgumentError do
          skadi.event(nil, {})
        end

        assert_equal "Skadi::ControllerDelegate.event expects String as first parameter, got NilClass", error.message
      end

      test "event with invalid properties" do
        error = assert_raises ArgumentError do
          skadi.event("name", nil)
        end

        assert_equal "Skadi::ControllerDelegate.event expects Hash as second parameter, got NilClass", error.message
      end
    end
  end
end

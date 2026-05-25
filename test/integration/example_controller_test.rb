require "integration/test_case"

module Skadi::Integration
  class ExampleControllerTest < TestCase
    def test_calculates_tracking_token_during_request
      Skadi.configuration.use_anonymisation_sets = true

      get example_index_path

      assert_response :success

      assert_equal 1, Skadi::Visit.count
      assert_equal 1, Skadi::View.count
    end

    def test_tracking_token_is_nil_when_anonymisation_sets_are_disabled
      Skadi.configuration.use_anonymisation_sets = false

      get example_index_path

      assert_response :success

      assert_equal 0, Skadi::Visit.count
      assert_equal 1, Skadi::View.count
    end
  end
end

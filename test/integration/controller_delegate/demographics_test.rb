require "integration/test_case"

module Skadi::Integration
  module ControllerDelegate
    class DemographicsTest < TestCase
      test "simple demographic" do
        get simple_demographic_path

        assert_response :ok

        assert_equal 1, Skadi::Demographic.count
        demographic = Skadi::Demographic.first!
        assert_equal "demographic", demographic.name
        assert_equal "simple", demographic.value
        assert_equal 1, demographic.count
        assert_equal Date.current, demographic.recorded_on
        assert_equal "", demographic.uri
      end

      test "multiple demographics" do
        get multiple_demographics_path

        assert_response :ok

        assert_equal 2, Skadi::Demographic.count
        general_demographic = Skadi::Demographic.first!
        view_demographic = Skadi::Demographic.last!

        assert_equal "demographic", general_demographic.name
        assert_equal "simple", general_demographic.value
        assert_equal 1, general_demographic.count
        assert_equal Date.current, general_demographic.recorded_on
        assert_equal "", general_demographic.uri

        assert_equal "demographic", view_demographic.name
        assert_equal "view", view_demographic.value
        assert_equal 1, view_demographic.count
        assert_equal Date.current, view_demographic.recorded_on
        assert_equal "/demographics/multiple(.:format)", view_demographic.uri
      end
    end
  end
end

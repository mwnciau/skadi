require "integration/test_case"

module Skadi::Integration
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

    test "multiple demographic" do
      get multiple_demographics_path

      assert_response :ok

      assert_equal 2, Skadi::Demographic.count
      demographic_1 = Skadi::Demographic.first!
      demographic_2 = Skadi::Demographic.last!

      assert_equal "demographic", demographic_1.name
      assert_equal "multiple_1", demographic_1.value
      assert_equal 1, demographic_1.count
      assert_equal Date.current, demographic_1.recorded_on

      assert_equal "demographic", demographic_2.name
      assert_equal "multiple_2", demographic_2.value
      assert_equal 2, demographic_2.count
      assert_equal Date.current, demographic_2.recorded_on
    end

    test "view demographic" do
      get view_demographic_path

      assert_response :ok

      assert_equal 1, Skadi::Demographic.count
      demographic = Skadi::Demographic.first!
      assert_equal "demographic", demographic.name
      assert_equal "view", demographic.value
      assert_equal 1, demographic.count
      assert_equal Date.current, demographic.recorded_on
      assert_equal "/demographics/view(.:format)", demographic.uri
    end
  end
end

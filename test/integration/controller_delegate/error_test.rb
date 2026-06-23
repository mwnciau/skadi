require "integration/test_case"

module Skadi::Integration
  module ControllerDelegate
    class ErrorTest < TestCase
      test "errors are raised and lgoged in test" do
        Skadi::View.any_instance.stubs(:save).raises(
          ActiveRecord::StatementInvalid, "simulated DB error"
        )
        Rails.logger.expects(:error).with(regexp_matches(/StatementInvalid.*simulated/))

        assert_raises ActiveRecord::StatementInvalid do
          get tracked_action_path
        end

        assert_equal 0, Skadi::View.count
      end

      test "errors are rescued and logged in production" do
        Rails.env = "production"

        Skadi::View.any_instance.stubs(:save).raises(
          ActiveRecord::StatementInvalid, "simulated DB error"
        )
        Rails.logger.expects(:error).with(regexp_matches(/StatementInvalid.*simulated/))

        get tracked_action_path

        assert_response :ok
        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
      ensure
        Rails.env = "test"
      end
    end
  end
end

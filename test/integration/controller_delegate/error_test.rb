require "integration/test_case"

module Skadi::Integration
  module ControllerDelegate
    class ErrorTest < TestCase
      test "errors are raised and logged in test env" do
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

      # This and the other error tests are to document the behaviour in the unexpected case there is
      # a DB error when persisting Skadi models
      test "nothing is persisted on visit save failure" do
        Rails.env = "production"
        Skadi::Visit.any_instance.stubs(:save).raises(
          ActiveRecord::StatementInvalid, "simulated DB error"
        )
        Rails.logger.expects(:error).at_least_once

        cookies[:skadi_id] = TRACKING_TOKEN
        get simple_event_path

        assert_response :ok
        assert_equal 0, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
        assert_equal 0, Skadi::Demographic.count
        assert_equal 0, Skadi::Event.count
      ensure
        Rails.env = "test"
      end

      test "only visit is persisted on view save failure" do
        Rails.env = "production"
        Skadi::View.any_instance.stubs(:save).raises(
          ActiveRecord::StatementInvalid, "simulated DB error"
        )
        Rails.logger.expects(:error).at_least_once

        cookies[:skadi_id] = TRACKING_TOKEN
        get simple_event_path

        assert_response :ok
        assert_equal 1, Skadi::Visit.count
        assert_equal 0, Skadi::View.count
        assert_equal 0, Skadi::Demographic.count
        assert_equal 0, Skadi::Event.count
      ensure
        Rails.env = "test"
      end

      test "visit and view are persisted on event insert failure" do
        Rails.env = "production"
        Skadi::Event.stubs(:insert_all).raises(
          ActiveRecord::StatementInvalid, "simulated DB error"
        )
        Rails.logger.expects(:error).at_least_once

        cookies[:skadi_id] = TRACKING_TOKEN
        get simple_event_path

        assert_response :ok
        assert_equal 1, Skadi::Visit.count
        assert_equal 1, Skadi::View.count
        assert_equal 0, Skadi::Event.count
        assert_equal 0, Skadi::Demographic.count
      ensure
        Rails.env = "test"
      end

      test "visit view, and events are persisted on demographic upsert failure" do
        Rails.env = "production"
        Skadi::Demographic.stubs(:create_or_increment_all).raises(
          ActiveRecord::StatementInvalid, "simulated DB error"
        )
        Rails.logger.expects(:error).at_least_once

        cookies[:skadi_id] = TRACKING_TOKEN
        get simple_event_path

        assert_response :ok
        assert_equal 1, Skadi::Visit.count
        assert_equal 1, Skadi::View.count
        assert_equal 1, Skadi::Event.count
        assert_equal 0, Skadi::Demographic.count
      ensure
        Rails.env = "test"
      end

      test "log line includes controller, action, visit id, and view id" do
        Rails.env = "production"
        Skadi::Event.stubs(:insert_all).raises(
          ActiveRecord::StatementInvalid, "simulated DB error"
        )

        log_io = StringIO.new
        original_logger = Rails.logger
        Rails.logger = ActiveSupport::Logger.new(log_io)

        cookies[:skadi_id] = TRACKING_TOKEN
        get simple_event_path

        visit = Skadi::Visit.last
        view = Skadi::View.last

        log = log_io.string
        assert_match(/events#simple/, log)
        assert_match(/StatementInvalid/, log)
        assert_match(/visit: #{visit.id}/, log)
        # If this fails, _persist is logging @visit.id under both keys (copy-paste at line 85).
        assert_match(/view: #{view.id}/, log)
      ensure
        Rails.env = "test"
        Rails.logger = original_logger if original_logger
      end
    end
  end
end

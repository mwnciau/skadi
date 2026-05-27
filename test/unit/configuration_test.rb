require_relative "test_case"

module Skadi::Unit
  class AnonymitySetTest < TestCase
    def setup
      @log = StringIO.new
      Rails.logger = Logger.new(@log)

      Skadi.configuration = Skadi::Configuration.new
    end

    test "default configuration is valid" do
      Skadi.configuration.validate!

      assert_empty @log.string
    end

    test "use_anonymisation_sets validates" do
      assert_values_are_valid(:use_anonymisation_sets, true, false)

      assert_values_are_invalid(:use_anonymisation_sets, nil, "true", "false", 123)
    end

    test "anonymisation_set_duration validates" do
      assert_values_are_valid(:anonymisation_set_duration, 5.minutes, 1.day, 1.hour, 3.weeks)

      assert_values_are_invalid(:anonymisation_set_duration, nil, "1 day", 123)
    end

    test "anonymisation_set_reset_hour validates" do
      assert_values_are_valid(:anonymisation_set_reset_hour, false, 0, 4, 23)

      assert_values_are_invalid(:anonymisation_set_reset_hour, nil, "2pm", 123)
    end

    test "visit_duration validates" do
      assert_values_are_valid(:visit_duration, 5.minutes, 1.day, 1.hour, 3.weeks)

      assert_values_are_invalid(:visit_duration, nil, "1 day", 123)
    end

    test "user_model validates" do
      assert_values_are_valid(:user_model, nil, Class.new(ActiveRecord::Base))

      assert_values_are_invalid(:user_model, Class.new, "User", :User)
    end

    test "user_method validates" do
      assert_values_are_valid(:user_method, nil, :current_user, :current_user_method)

      assert_values_are_invalid(:user_method, "Current.user", "current_user")
    end

    test "use_query_param_whitelist validates" do
      assert_values_are_valid(:use_query_param_whitelist, true, false)

      assert_values_are_invalid(:use_query_param_whitelist, nil, "true", "false", 123)
    end

    test "query_param_whitelist validates" do
      assert_values_are_valid(:query_param_whitelist, [], [:symbol], [:two, :symbols])

      assert_values_are_invalid(:query_param_whitelist, ["string"], [:symbol, "string"], :symbol, {symbol: true})
    end

    test "db_connects_to validates" do
      assert_values_are_valid(:db_connects_to, nil, {database: :primary}, {database: :primary, shards: :all}, {shards: :all})

      assert_values_are_invalid(:db_connects_to, {}, {invalid_key: true}, {database: :primary, invalid_key: true})
    end

    test "store_domain_in_views validates" do
      assert_values_are_valid(:store_domain_in_views, true, false)

      assert_values_are_invalid(:store_domain_in_views, nil, "true", "false", 123)
    end

    private def assert_values_are_valid(attribute, *values)
      values.each do |value|
        Skadi.configuration.send("#{attribute}=", value)
        Skadi.configuration.validate!

        assert_empty @log.string
      end
    end

    private def assert_values_are_invalid(attribute, *values)
      values.each do |value|
        Skadi.configuration.send("#{attribute}=", value)
        Skadi.configuration.validate!

        assert_match("Skadi.configuration.#{attribute} error!", @log.string, "Expected error message for #{attribute}=#{value.inspect}")

        # Reset the log for the next iteration
        @log.string = ""
      end
    end
  end
end

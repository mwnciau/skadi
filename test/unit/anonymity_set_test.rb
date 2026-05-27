require_relative "test_case"

module Skadi::Unit
  class AnonymitySetTest < TestCase
    test "calculate returns a uuid" do
      anonymity_set = Skadi::AnonymitySet.calculate("1.2.3.4", "Test user agent")

      assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, anonymity_set)
    end

    test "calculate returns a consistent value" do
      anonymity_set_1 = Skadi::AnonymitySet.calculate("1.2.3.4", "Test user agent")
      anonymity_set_2 = Skadi::AnonymitySet.calculate("1.2.3.4", "Test user agent")

      assert_equal anonymity_set_1, anonymity_set_2
    end

    test "calculate returns nil if anonymisation sets are disabled" do
      Skadi.configuration.use_anonymisation_sets = false

      anonymity_set = Skadi::AnonymitySet.calculate("1.2.3.4", "Test user agent")

      assert_nil anonymity_set
    end

    test "anonymity_set_pepper returns a consistent value until reset hour" do
      Skadi.configuration.anonymisation_set_reset_hour = 3

      pepper_1 = travel_to Time.zone.now.change(hour: 3, min: 1) do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      pepper_2 = travel_to Time.zone.now.change(hour: 2, min: 59) + 1.day do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      assert_equal pepper_1, pepper_2
    end

    test "anonymity_set_pepper changes after reset hour" do
      Skadi.configuration.anonymisation_set_reset_hour = 3

      pepper_1 = travel_to Time.zone.now.change(hour: 2, min: 59) do
        Skadi::AnonymitySet.anonymity_set_pepper
      end
      pepper_2 = travel_to Time.zone.now.change(hour: 3, min: 1) do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      assert_match(/\A[0-9a-f]{64}\z/, pepper_1)
      assert_match(/\A[0-9a-f]{64}\z/, pepper_2)
      refute_equal pepper_1, pepper_2
    end

    test "anonymity_set_pepper reset hour can be changed" do
      Skadi.configuration.anonymisation_set_reset_hour = 15

      pepper_1 = travel_to Time.zone.now.change(hour: 14, min: 59) do
        Skadi::AnonymitySet.anonymity_set_pepper
      end
      pepper_2 = travel_to Time.zone.now.change(hour: 15, min: 1) do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      assert_match(/\A[0-9a-f]{64}\z/, pepper_1)
      assert_match(/\A[0-9a-f]{64}\z/, pepper_2)
      refute_equal pepper_1, pepper_2
    end

    test "anonymity_set_pepper reset hour takes precendence over short durations" do
      # If the duration is less than a day and the reset hour is set, the duration essentially becomes one day
      Skadi.configuration.anonymisation_set_duration = 1.minute
      Skadi.configuration.anonymisation_set_reset_hour = 3

      pepper_1 = travel_to Time.zone.now.change(hour: 3, min: 1) do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      pepper_2 = travel_to Time.zone.now.change(hour: 2, min: 59) + 1.day do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      assert_equal pepper_1, pepper_2
    end

    test "anonymity_set_pepper duration can be changed" do
      # If the duration is less than a day and the reset hour is set, the duration essentially becomes one day
      Skadi.configuration.anonymisation_set_duration = 2.days
      Skadi.configuration.anonymisation_set_reset_hour = 3

      pepper_1 = travel_to Time.zone.now.change(hour: 3, min: 1) do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      pepper_2 = travel_to Time.zone.now.change(hour: 2, min: 59) + 1.day do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      pepper_3 = travel_to Time.zone.now.change(hour: 2, min: 59) + 2.days do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      different_pepper = travel_to Time.zone.now.change(hour: 3, min: 1) + 2.days do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      assert_equal pepper_1, pepper_2
      assert_equal pepper_1, pepper_3
      refute_equal pepper_1, different_pepper
    end

    test "anonymity_set_pepper uses raw duration when reset hour is nil" do
      Skadi.configuration.anonymisation_set_duration = 5.minutes
      Skadi.configuration.anonymisation_set_reset_hour = nil

      pepper_1 = Skadi::AnonymitySet.anonymity_set_pepper

      pepper_2 = travel 6.minutes do
        Skadi::AnonymitySet.anonymity_set_pepper
      end

      refute_equal pepper_1, pepper_2
    end
  end
end
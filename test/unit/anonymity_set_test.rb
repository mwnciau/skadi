require_relative "test_case"

module Skadi::Unit
  class AnonymitySetTest < TestCase
    test "calculate returns a uuid" do
      Skadi.configuration.use_anonymity_sets = true

      anonymity_set = Skadi::AnonymitySet.calculate("1.2.3.4", "Test user agent")

      assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, anonymity_set)
    end

    test "calculate returns a consistent value" do
      Skadi.configuration.use_anonymity_sets = true

      anonymity_set_1 = Skadi::AnonymitySet.calculate("1.2.3.4", "Test user agent")
      anonymity_set_2 = Skadi::AnonymitySet.calculate("1.2.3.4", "Test user agent")

      assert_equal anonymity_set_1, anonymity_set_2
    end

    test "calculate returns nil if anonymity sets are disabled" do
      anonymity_set = Skadi::AnonymitySet.calculate("1.2.3.4", "Test user agent")

      assert_nil anonymity_set
    end

    test "pepper returns a consistent value until reset hour" do
      Skadi.configuration.anonymity_set_reset_hour = 3

      pepper_1 = travel_to Time.zone.now.change(hour: 3, min: 1) do
        Skadi::AnonymitySet.pepper
      end

      pepper_2 = travel_to Time.zone.now.change(hour: 2, min: 59) + 1.day do
        Skadi::AnonymitySet.pepper
      end

      assert_equal pepper_1, pepper_2
    end

    test "pepper changes after reset hour" do
      Skadi.configuration.anonymity_set_reset_hour = 3

      pepper_1 = travel_to Time.zone.now.change(hour: 2, min: 59) do
        Skadi::AnonymitySet.pepper
      end
      pepper_2 = travel_to Time.zone.now.change(hour: 3, min: 1) do
        Skadi::AnonymitySet.pepper
      end

      assert_match(/\A[0-9a-f]{64}\z/, pepper_1)
      assert_match(/\A[0-9a-f]{64}\z/, pepper_2)
      refute_equal pepper_1, pepper_2
    end

    test "pepper reset hour can be changed" do
      Skadi.configuration.anonymity_set_reset_hour = 15

      pepper_1 = travel_to Time.zone.now.change(hour: 14, min: 59) do
        Skadi::AnonymitySet.pepper
      end
      pepper_2 = travel_to Time.zone.now.change(hour: 15, min: 1) do
        Skadi::AnonymitySet.pepper
      end

      assert_match(/\A[0-9a-f]{64}\z/, pepper_1)
      assert_match(/\A[0-9a-f]{64}\z/, pepper_2)
      refute_equal pepper_1, pepper_2
    end

    test "pepper reset hour takes precendence over short durations" do
      # If the duration is less than a day and the reset hour is set, the duration essentially becomes one day
      Skadi.configuration.anonymity_set_duration = 1.minute
      Skadi.configuration.anonymity_set_reset_hour = 3

      pepper_1 = travel_to Time.zone.now.change(hour: 3, min: 1) do
        Skadi::AnonymitySet.pepper
      end

      pepper_2 = travel_to Time.zone.now.change(hour: 2, min: 59) + 1.day do
        Skadi::AnonymitySet.pepper
      end

      assert_equal pepper_1, pepper_2
    end

    test "pepper duration can be changed" do
      # If the duration is less than a day and the reset hour is set, the duration essentially becomes one day
      Skadi.configuration.anonymity_set_duration = 2.days
      Skadi.configuration.anonymity_set_reset_hour = 3

      pepper_1 = travel_to Time.zone.now.change(hour: 3, min: 1) do
        Skadi::AnonymitySet.pepper
      end

      pepper_2 = travel_to Time.zone.now.change(hour: 2, min: 59) + 1.day do
        Skadi::AnonymitySet.pepper
      end

      pepper_3 = travel_to Time.zone.now.change(hour: 2, min: 59) + 2.days do
        Skadi::AnonymitySet.pepper
      end

      different_pepper = travel_to Time.zone.now.change(hour: 3, min: 1) + 2.days do
        Skadi::AnonymitySet.pepper
      end

      assert_equal pepper_1, pepper_2
      assert_equal pepper_1, pepper_3
      refute_equal pepper_1, different_pepper
    end

    test "pepper uses raw duration when reset hour is nil" do
      Skadi.configuration.anonymity_set_duration = 5.minutes
      Skadi.configuration.anonymity_set_reset_hour = nil

      pepper_1 = Skadi::AnonymitySet.pepper

      pepper_2 = travel 6.minutes do
        Skadi::AnonymitySet.pepper
      end

      refute_equal pepper_1, pepper_2
    end
  end
end

require "integration/test_case"

module Skadi::Integration
  class AnonymisationSetTest < TestCase
    TEST_IP = "127.0.0.1"
    TEST_USER_AGENT = "Test User Agent"
    DEFAULT_HEADERS = { "HTTP_USER_AGENT" => TEST_USER_AGENT, "REMOTE_ADDR" => TEST_IP, "REFERER" => "https://example.com" }

    setup do
      Skadi.configuration.use_anonymisation_sets = true
    end

    test "anonymisation set is reused between visits" do
      3.times { get_tracked_action }

      assert_equal 1, Skadi::Visit.count
      assert_equal 3, Skadi::View.count

      visit = Skadi::Visit.first!
      refute_nil visit.tracking_token
    end

    test "anonymisation set is changed on IP or User Agent change" do
      get_tracked_action
      get_tracked_action(user_agent: "Different User Agent")
      get_tracked_action(ip: "10.0.0.1")

      assert_equal 3, Skadi::Visit.count
      assert_equal 3, Skadi::View.count

      anonymisation_set_ids = Skadi::Visit.pluck(:tracking_token).uniq
      assert_equal 3, anonymisation_set_ids.size
    end

    test "anonymisation set is disabled by configuration" do
      Skadi.configuration.use_anonymisation_sets = false

      get_tracked_action(referrer: "https://example.com/something")
      get_tracked_action(referrer: "https://example.com/other")

      assert_equal 2, Skadi::Visit.count
      assert_equal 2, Skadi::View.count

      anonymisation_set_ids = Skadi::Visit.pluck(:tracking_token)
      assert_nil anonymisation_set_ids[0]
      assert_nil anonymisation_set_ids[1]
    end

    # Todo: this test in inconsistent. Write some unit tests!
    test "anonymisation set is reset after reset hour" do
      travel_to Time.zone.now.change(hour: 2, min: 50) do
        get_tracked_action
      end

      # Travel to just after the default reset hour, 3am
      travel_to Time.zone.now.change(hour: 3, min: 10) do
        get_tracked_action
      end

      # The anonymisation set id should have changed between the two requests, so we expect two visits
      assert_equal 2, Skadi::Visit.count
      assert_equal 2, Skadi::View.count

      # Ensure the two visits have different anonymisation set ids
      anonymisation_set_ids = Skadi::Visit.pluck(:tracking_token)
      refute_equal anonymisation_set_ids[0], anonymisation_set_ids[1]
    end
  end
end

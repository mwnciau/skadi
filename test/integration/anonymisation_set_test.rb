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
      3.times { get example_index_path, headers: DEFAULT_HEADERS }

      assert_equal 1, Skadi::Visit.count
      assert_equal 3, Skadi::View.count

      visit = Skadi::Visit.first!
      refute_nil visit.tracking_token
    end

    test "anonymisation set is changed on IP or User Agent change" do
      get example_index_path, headers: DEFAULT_HEADERS
      get example_index_path, headers: {**DEFAULT_HEADERS, "HTTP_USER_AGENT" => "Different User Agent"}
      get example_index_path, headers: {**DEFAULT_HEADERS, "REMOTE_ADDR" => "192.168.1.1"}

      assert_equal 3, Skadi::Visit.count
      assert_equal 3, Skadi::View.count

      anonymisation_set_ids = Skadi::Visit.pluck(:tracking_token).uniq
      assert_equal 3, anonymisation_set_ids.size
    end

    test "anonymisation set is disabled by configuration" do
      Skadi.configuration.use_anonymisation_sets = false

      get example_index_path, headers: DEFAULT_HEADERS
      get example_index_path, headers: DEFAULT_HEADERS

      assert_equal 2, Skadi::Visit.count
      assert_equal 2, Skadi::View.count

      anonymisation_set_ids = Skadi::Visit.pluck(:tracking_token)
      assert_nil anonymisation_set_ids[0]
      assert_nil anonymisation_set_ids[1]
    end

    test "anonymisation set is reset after reset hour" do
      travel_to Time.zone.now.change(hour: 2, min: 59) do
        get example_index_path, headers: DEFAULT_HEADERS
      end

      # Travel to just after the default reset hour, 3am
      travel_to Time.zone.now.change(hour: 3, min: 1) do
        get example_index_path, headers: DEFAULT_HEADERS
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

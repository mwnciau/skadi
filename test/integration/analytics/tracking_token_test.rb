require "integration/test_case"

module Skadi::Integration
  module Analytics
    class TrackingTokenTest < TestCase
      TEST_IP = "127.0.0.1"
      TEST_USER_AGENT = "Test User Agent"
      DEFAULT_HEADERS = {"HTTP_USER_AGENT" => TEST_USER_AGENT, "REMOTE_ADDR" => TEST_IP, "REFERER" => "https://example.com"}

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

        get_tracked_action(referrer: "https://example.com/")

        assert_equal 1, Skadi::Visit.count
        assert_equal 1, Skadi::View.count

        visit = Skadi::Visit.first
        assert_nil visit.tracking_token
      end

      test "anonymisation set is disabled by opt out track cookie" do
        cookies["skadi_tracking_opt_out"] = "1"

        get_tracked_action(referrer: "https://example.com/")

        assert_equal 1, Skadi::Visit.count
        assert_equal 1, Skadi::View.count

        visit = Skadi::Visit.first
        assert_nil visit.tracking_token
      end

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

      test "tracking cookie takes precedence over anonymisation set" do
        cookies["skadi_id"] = "00000000-0000-0000-0000-000000000000"

        get_tracked_action

        visit = Skadi::Visit.first!
        assert_equal "00000000-0000-0000-0000-000000000000", visit.tracking_token
      end

      test "tracking cookie is ignored with opt out cookie" do
        cookies["skadi_tracking_opt_out"] = "1"
        cookies["skadi_id"] = "00000000-0000-0000-0000-000000000000"

        get_tracked_action(referrer: "https://example.com/")

        visit = Skadi::Visit.first!
        assert_nil visit.tracking_token
      end

      test "tracking cookie is ignored if not a valid uuid" do
        # Opt out so visits are created for each request
        cookies["skadi_tracking_opt_out"] = "1"

        [
          "invalid",
          # Short
          "00000000-0000-0000-0000-00000000000",
          # Long
          "00000000-0000-0000-0000-0000000000000",
          # Invalid characters
          "00000000-0000-0000-0000-00000000000x",
          # Missing dashes
          "00000000000000000000000000000000",
          # Really long
          "00000000-0000-0000-0000-000000000000-0000-0000-0000-000000000000" * 10,
        ].each do |invalid_uuid|
          cookies["skadi_id"] = invalid_uuid

          assert_difference -> { Skadi::Visit.count }, 1, "expecting a visit to be created for uuid #{invalid_uuid}" do
            get_tracked_action(referrer: "https://example.com/")
          end

          visit = Skadi::Visit.last!
          refute_equal invalid_uuid, visit.tracking_token, "expecting invalid uuid to not be saved #{invalid_uuid}"
        end
      end
    end
  end
end

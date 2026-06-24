require_relative "test_case"

module Skadi::Unit
  class DemographicTest < TestCase
    test "create_or_increment_all creates a new row" do
      Skadi::Demographic.create_or_increment_all([{name: "Browser", value: "Chrome"}])

      assert_equal 1, Skadi::Demographic.count

      demographic = Skadi::Demographic.first!
      assert_equal "Browser", demographic.name
      assert_equal "Chrome", demographic.value
      assert_equal "", demographic.uri
      assert_equal 1, demographic.count
      assert_equal Date.current, demographic.recorded_on
    end

    test "create_or_increment_all nil uri is stored as empty string" do
      Skadi::Demographic.create_or_increment_all([{name: "Browser", value: "Chrome", uri: nil}])

      assert_equal "", Skadi::Demographic.first!.uri
    end

    test "create_or_increment_all strips whitespace from name, value, and uri" do
      Skadi::Demographic.create_or_increment_all([{
        name: "  Browser  ",
        value: "  Chrome  ",
        uri: "  /foo  ",
      }])

      demographic = Skadi::Demographic.first!
      assert_equal "Browser", demographic.name
      assert_equal "Chrome", demographic.value
      assert_equal "/foo", demographic.uri
    end

    test "create_or_increment_all truncates name, value, and uri to 255 characters" do
      long = "a" * 300

      Skadi::Demographic.create_or_increment_all([{name: long, value: long, uri: long}])

      demographic = Skadi::Demographic.first!
      assert_equal 255, demographic.name.length
      assert_equal 255, demographic.value.length
      assert_equal 255, demographic.uri.length
    end

    test "create_or_increment_all increments count on duplicate across calls" do
      Skadi::Demographic.create_or_increment_all([{name: "Browser", value: "Chrome"}])
      Skadi::Demographic.create_or_increment_all([{name: "Browser", value: "Chrome"}])
      Skadi::Demographic.create_or_increment_all([{name: "Browser", value: "Chrome"}])

      assert_equal 1, Skadi::Demographic.count
      assert_equal 3, Skadi::Demographic.first!.count
    end

    test "create_or_increment_all different uris are stored as separate rows" do
      Skadi::Demographic.create_or_increment_all([{name: "Browser", value: "Chrome", uri: "/a"}])
      Skadi::Demographic.create_or_increment_all([{name: "Browser", value: "Chrome", uri: "/b"}])

      assert_equal 2, Skadi::Demographic.count
    end

    test "create_or_increment_all different values are stored as separate rows" do
      Skadi::Demographic.create_or_increment_all([{name: "Browser", value: "Chrome"}])
      Skadi::Demographic.create_or_increment_all([{name: "Browser", value: "Firefox"}])

      assert_equal 2, Skadi::Demographic.count
    end
  end
end

require_relative "test_case"

module Skadi::Unit
  class UserAgentTest < TestCase
    MOBILE_BROWSERS = %w[Firefox Safari Chrome]
    MOBILE_OSES = %w[iOS Android]
    BROWSER_TEST_FILE = File.join(__dir__, "../fixtures/user_agent/user_agents.json")
    BOT_TEST_FILE = File.join(__dir__, "../fixtures/user_agent/bot_user_agents.json")

    test "parse accuracy" do
      dataset = JSON.load_file(BROWSER_TEST_FILE)

      errors =  dataset["userAgents"].sum do |test_case|
        user_agent = Skadi::UserAgent.new(test_case["userAgent"])
        count = test_case["count"]

        # Reformat the test data to be consistent with how we present the data
        if MOBILE_BROWSERS.include?(test_case["browser"]) && MOBILE_OSES.include?(test_case["os"])
          test_case["browser"] = "#{test_case["browser"]} for #{test_case["os"]}"
        end

        next count unless  userAgent.browser == test_case["browser"]
        next count unless test_case["browserMajorVersion"] ==  userAgent.browser_version

        next count unless user_agent.browser == test_case["browser"]
        next count unless test_case["browserMajorVersion"] ==  user_agent.browser_version

        next count unless test_case["engine"] ==  user_agent.engine
        next count unless test_case["engineMajorVersion"] ==  user_agent.engine_version

        next count unless test_case["os"] ==  user_agent.os

        # If everything matches, there are no errors so return 0
        0
      end

      # Assert that the error rate is less than 0.5%
      assert 100.0 * errors / dataset["totalCount"] < 0.5
    end

    test "bot accuracy on browser dataset" do
      dataset = JSON.load_file(BROWSER_TEST_FILE)

      false_positives = 0
      false_negatives = 0

      dataset["userAgents"].each do |test_case|
        userAgent = Skadi::UserAgent.new(test_case["userAgent"])
        count = test_case["count"]

        if userAgent.bot? && !test_case["isBot"]
          false_positives += count
        end

        if userAgent.human? && test_case["isBot"]
          false_negatives += count
        end
      end

      # Todo: the source dataset isn't very good at detecting bots and I think we do it better...
      # Assert that the error rate is less than 1%
      assert 100.0 * false_positives / dataset["totalCount"] < 1
      assert 100.0 * false_negatives / dataset["totalCount"] < 1
    end

    test "bot accuracy on bot dataset" do
      dataset = JSON.load_file(BOT_TEST_FILE)

      false_negatives = 0

      dataset["userAgents"].each do |test_case|
        userAgent = Skadi::UserAgent.new(test_case["userAgent"])

        unless userAgent.bot?
          false_negatives += test_case["count"]
        end
      end

      # Assert that the error rate is less than 0.1%
      assert 100.0 * false_negatives / dataset["totalCount"] < 0.1
    end

    test "performance" do
      skip("Benchmarking libraries are not installed") unless maybe_require("benchmark/ips")

      maybe_require "browser"
      maybe_require "device_detector"

      dataset = JSON.load_file(BROWSER_TEST_FILE)
      dataset_size = dataset["userAgents"].length

      Benchmark.ips do |bm|
        i = 0
        bm.report("skadi") do
          result = Skadi::UserAgent.new(dataset["userAgents"][i]["userAgent"])
          result.browser
          result.browser_version
          result.os
          result.bot?

          i = (i + 1) % dataset_size
        end

        i = 0
        bm.report("browser") do
          result = Browser.new(dataset["userAgents"][i]["userAgent"])
          result.name
          result.version
          result.platform.name
          result.bot?

          i = (i + 1) % dataset_size
        end if defined?(Browser)

        bm.report("device_detector") do
          result = DeviceDetector.new(dataset["userAgents"][i]["userAgent"])
          result.name
          result.full_version
          result.os_name
          result.bot?

          i = (i + 1) % dataset_size
        end if defined?(DeviceDetector)

        bm.compare!
      end
    end

    private def maybe_require(library)
      require library
    rescue LoadError
      false
    end
  end
end

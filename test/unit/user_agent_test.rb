require_relative "test_case"

module Skadi::Unit
  class UserAgentTest < TestCase
    MOBILE_BROWSERS = %w[Firefox Safari Chrome]
    MOBILE_OSES = %w[iOS Android]
    BROWSER_TEST_FILE = File.join(__dir__, "../fixtures/user_agent/user_agents.json")

    test "parse accuracy" do
      dataset = JSON.load_file(BROWSER_TEST_FILE)

      errors =  dataset["userAgents"].sum do |test_case|
        result = Skadi::UserAgent.parse(test_case["userAgent"])
        count = test_case["count"]

        # Reformat the test data to be consistent with how we present the data
        if MOBILE_BROWSERS.include?(test_case["browser"]) && MOBILE_OSES.include?(test_case["os"])
          test_case["browser"] = "#{test_case["browser"]} for #{test_case["os"]}"
        end

        next count unless result[:browser] == test_case["browser"]
        next count unless test_case["browserMajorVersion"] == result[:browser_version]

        next count unless test_case["engine"] == result[:engine]
        next count unless test_case["engineMajorVersion"] == result[:engine_version]

        next count unless test_case["os"] == result[:os]

        # If everything matches, there are no errors so return 0
        0
      end

      # Assert that the error rate is less than 0.5%
      assert 100.0 * errors / dataset["totalCount"] < 0.5
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
          result = Skadi::UserAgent.parse(dataset["userAgents"][i]["userAgent"])
          result[:browser]
          result[:browser_version]
          result[:os]

          i = (i + 1) % dataset_size
        end

        i = 0
        bm.report("browser") do
          result = Browser.new(dataset["userAgents"][i]["userAgent"])
          result.name
          result.version
          result.platform.name

          i = (i + 1) % dataset_size
        end if defined?(Browser)

        bm.report("device_detector") do
          result = DeviceDetector.new(dataset["userAgents"][i]["userAgent"])
          result.name
          result.full_version
          result.os_name

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

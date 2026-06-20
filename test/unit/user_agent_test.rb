require_relative "test_case"

module Skadi::Unit
  class UserAgentTest < TestCase
    # Set to true to enable debug output during tests
    UA_DEBUG = false

    MOBILE_BROWSERS = %w[Firefox Safari Chrome Edge]
    MOBILE_OSES = %w[iOS Android]
    BROWSER_TEST_FILE = File.join(__dir__, "../fixtures/user_agent/user_agents.json")
    BOT_TEST_FILE = File.join(__dir__, "../fixtures/user_agent/bot_user_agents.json")

    # Testing against the [May 2026 Intoli dataset](https://github.com/mwnciau/user_agent_dumps/tree/main/intoli_user_agents),
    # there are 13 errors (0.08%). Those errors are TikTokLIVEStudio not being correctly identified in the source data,
    # MQQ browser being identified as QQBrowser in the source data, and a legacy Safari user agent where the version is
    # "Unknown" insteaf of "1" - this is the only incorrect parsing, and chosen to be ignored for performance and
    # because of the relative scarcity of the browser.
    test "parse accuracy" do
      dataset = JSON.load_file(BROWSER_TEST_FILE)

      errors =  dataset["userAgents"].sum do |test_case|
        user_agent = Skadi::UserAgent.new(test_case["userAgent"])
        count = test_case["count"]

        # Reformat the test data to be consistent with how we present the data
        if MOBILE_BROWSERS.include?(test_case["browser"]) && MOBILE_OSES.include?(test_case["os"])
          test_case["browser"] = "#{test_case["browser"]} for #{test_case["os"]}"
        end

        show_parse_error(user_agent, test_case) if UA_DEBUG

        next count unless user_agent.browser == test_case["browser"]
        next count unless test_case["browserMajorVersion"] ==  user_agent.browser_version

        next count unless test_case["engine"] ==  user_agent.engine
        next count unless test_case["engineMajorVersion"] ==  user_agent.engine_version

        next count unless test_case["os"] ==  user_agent.os

        # If everything matches, there are no errors so return 0
        0
      end

      puts "Error rate: #{(100.0 * errors / dataset["totalCount"]).round(2)}% (#{errors})" if UA_DEBUG

      # Assert that the error rate is less than 0.5%
      assert 100.0 * errors / dataset["totalCount"] < 0.5
    end

    private def show_parse_error(user_agent, test_case)
      return if user_agent.browser == test_case["browser"] && test_case["browserMajorVersion"] ==  user_agent.browser_version && test_case["engine"] ==  user_agent.engine && test_case["engineMajorVersion"] ==  user_agent.engine_version && test_case["os"] ==  user_agent.os

      puts "----------------------------------------"
      puts "User agent: #{test_case["userAgent"]}"

      puts "Browser detected '#{user_agent.browser}' should be '#{test_case["browser"]}'" unless user_agent.browser == test_case["browser"]
      puts "Browser version detected '#{user_agent.browser_version}' should be '#{test_case["browserMajorVersion"]}'" unless test_case["browserMajorVersion"] ==  user_agent.browser_version

      puts "Engine detected '#{user_agent.engine}' should be '#{test_case["engine"]}'" unless user_agent.engine == test_case["engine"]
      puts "Engine version detected '#{user_agent.engine_version}' should be '#{test_case["engineMajorVersion"]}'" unless test_case["engineMajorVersion"] ==  user_agent.engine_version

      puts "OS detected '#{user_agent.os}' should be '#{test_case["os"]}'" unless user_agent.os == test_case["os"]

      puts "----------------------------------------"
      puts ""
    end

    # Testing against the [May 2026 Intoli dataset](https://github.com/mwnciau/user_agent_dumps/tree/main/intoli_user_agents),
    # there are no false negatives and 302 (0.0%) false positives for `Code` AI crawler user agents, repesenting an issue with
    # the source dataset.
    #
    # Testing against the bundled dataset, the error rate is much higher (0.8%), but the reported false positive user
    # agents all look like bots.
    test "bot accuracy on browser dataset" do
      dataset = JSON.load_file(BROWSER_TEST_FILE)

      false_positives = 0
      false_negatives = 0

      errors = []

      dataset["userAgents"].each do |test_case|
        user_agent = Skadi::UserAgent.new(test_case["userAgent"])
        count = test_case["count"]

        if user_agent.bot? && !test_case["isBot"]
          false_positives += count
          errors << "False positive: #{test_case["userAgent"]} (#{count})"
        end

        if user_agent.human? && test_case["isBot"]
          false_negatives += count
          errors << "False negative: #{test_case["userAgent"]} (#{count})"
        end
      end

      if UA_DEBUG
        puts "false positives: #{(100.0 * false_positives / dataset["totalCount"]).round(2)}% (#{false_positives})"
        puts "false negatives: #{(100.0 * false_negatives / dataset["totalCount"]).round(2)}% (#{false_negatives})"
        puts ""
        puts errors
      end

      # Todo: the source dataset isn't very good at detecting bots and I think we do it better...
      # Assert that the error rate is less than 1%
      assert 100.0 * false_positives / dataset["totalCount"] < 1
      assert 100.0 * false_negatives / dataset["totalCount"] < 1
    end

    # Testing against the [crawler user agent](https://github.com/monperrus/crawler-user-agents) dataset, the bot
    # detector currently has one false negative against a potential real snapchat user agent.
    test "bot accuracy on bot dataset" do
      dataset = JSON.load_file(BOT_TEST_FILE)

      false_negatives = 0
      errors = []

      dataset["userAgents"].each do |test_case|
        user_agent = Skadi::UserAgent.new(test_case["userAgent"])

        unless user_agent.bot?
          false_negatives += test_case["count"]
          errors << "False negative: #{test_case["userAgent"]} (#{test_case["count"]})"
        end
      end

      if UA_DEBUG
        puts "false negatives: #{(100.0 * false_negatives / dataset["totalCount"]).round(2)}% (#{false_negatives})"
        puts ""
        puts errors
      end

      # Assert that the error rate is less than 0.1%
      assert 100.0 * false_negatives / dataset["totalCount"] < 0.1
    end

    # Testing against the [May 2026 Intoli dataset](https://github.com/mwnciau/user_agent_dumps/tree/main/intoli_user_agents)
    # of real-world user agent tokens, the Skadi parser is 9 times faster than the `browser` gem and over 100 times
    # faster than the `device_detector` gem. Benchmark output:
    #
    # Comparison:
    #           skadi:   111271.7 i/s
    #         browser:    12178.7 i/s - 9.14x  slower
    # device_detector:     1100.3 i/s - 101.13x  slower
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

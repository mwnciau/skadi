require_relative "test_case"

module Skadi::Unit
  class UserAgentTest < TestCase
    MOBILE_BROWSERS = %w[Firefox Safari Chrome]
    MOBILE_OSES = %w[iOS Android]
    BROWSER_MAPPING = {
      "Baidu" => "baiduboxapp",
      "Chrome Headless" => "HeadlessChrome",
      "Huawei Browser" => "HuaweiBrowser",
      "MIUI Browser" => "MiuiBrowser",
      "Samsung Internet" => "SamsungBrowser",
      "Vivo Browser" => "VivoBrowser",
      "Yandex" => "YaBrowser",
    }
    UNSUPPPORTED_BROWSERS = %w[Mozilla]

    test "parse desktop user agents" do
      dataset = JSON.load_file(File.join(__dir__, "../fixtures/user_agent/user_agents.json"))

      positive = 0
      negative = 0

      browser_errors = Hash.new { |h, k| h[k] = 0 }
      engine_errors = Hash.new { |h, k| h[k] = 0 }

      shown = 0
      errors = []

      dataset["userAgents"].each do |test_case|
        result = Skadi::UserAgent.parse(test_case["userAgent"])

        browser_match, browser_version_match, engine_match, engine_version_match = nil

        if MOBILE_BROWSERS.include?(test_case["browser"]) && MOBILE_OSES.include?(test_case["os"])
          test_case["browser"] = "#{test_case["browser"]} for #{test_case["os"]}"
        end
        if BROWSER_MAPPING.key?(test_case["browser"])
          test_case["browser"] = BROWSER_MAPPING[test_case["browser"]]
        end

        browser_match = result[:browser] == test_case["browser"]
        browser_version_match = test_case["browserMajorVersion"] == result[:browser_version] || test_case["browser"] == "Unknown"

        engine_match = test_case["engine"] == result[:engine]
        engine_version_match = test_case["engineMajorVersion"] == result[:engine_version] || test_case["engine"] == "Unknown"

        if browser_match && engine_match && browser_version_match && engine_version_match
          positive += test_case["count"]
        else
          negative += test_case["count"]

          engine_errors[test_case["engine"]] += test_case["count"] if !engine_match || !engine_version_match
          browser_errors[test_case["browser"]] += test_case["count"] if !browser_match || !browser_version_match

          next if shown >= 20
          shown += 1

          errors << "----------------------------------------"
          errors << "Showing #{browser_errors[test_case["browser"]]} (#{test_case["count"]}) of #{dataset["totalCount"]} errors"
          errors << "User agent: #{test_case["userAgent"]}"
          errors << "Browser: '#{result[:browser]}' #{browser_match ? "✅" : "❌"} (#{test_case["browser"]})"
          errors << "Browser version: '#{result[:browser_version]}' #{browser_version_match ? "✅" : "❌"}  (#{test_case["browserMajorVersion"]})"
          errors << "Engine: #{result[:engine]} #{engine_match ? "✅" : "❌"} (#{test_case["engine"]})"
          errors << "Engine version: #{result[:engine_version]} #{engine_version_match ? "✅" : "❌"}  (#{test_case["engineMajorVersion"]})"

          errors << "----------------------------------------"
          errors << ""
        end
      end

      puts "Positive: #{positive} (#{(100 * positive.to_f / dataset["totalCount"]).round}%)"
      puts "Negative: #{negative} (#{(100 * negative.to_f / dataset["totalCount"]).round}%)"
      puts ""
      puts "Browser errors: #{browser_errors.to_a.sort { |a, b| a[1] <=> b[1] }.reverse.map{|k,v| "#{k} (#{v})" }.join(", ")}"
      puts "Engine errors: #{engine_errors.to_a.sort { |a, b| a[1] <=> b[1] }.reverse.map{|k,v| "#{k} (#{v})" }.join(", ")}"
      puts ""
      errors.each { |e| puts e }
    end

    test "single ua" do
      # Should be GSA
      ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) GSA/295.0.590048842 Mobile/15E148 Safari/604.1"

      # Should be Android Browser
      ua = "Mozilla/5.0 (Linux; Android 4.0.0; SM-T560 Build/KTU84P) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/33.0.0.0 Safari/537.0 GSA/9.0.0.0.arm"

      puts "browser: #{Skadi::UserAgent.parse_browser(ua).inspect}"
      puts "engine: #{Skadi::UserAgent.parse_engine(ua).inspect}"
      puts "os: #{Skadi::UserAgent.parse_os(ua).inspect}"
      end
  end
end

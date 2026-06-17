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
        userAgent = Skadi::UserAgent.new(test_case["userAgent"])
        count = test_case["count"]

        # Reformat the test data to be consistent with how we present the data
        if MOBILE_BROWSERS.include?(test_case["browser"]) && MOBILE_OSES.include?(test_case["os"])
          test_case["browser"] = "#{test_case["browser"]} for #{test_case["os"]}"
        end

        next count unless  userAgent.browser == test_case["browser"]
        next count unless test_case["browserMajorVersion"] ==  userAgent.browser_version

        next count unless test_case["engine"] ==  userAgent.engine
        next count unless test_case["engineMajorVersion"] ==  userAgent.engine_version

        next count unless test_case["os"] ==  userAgent.os

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



    test "lookup performance" do
      skip("Benchmarking libraries are not installed") unless maybe_require("benchmark/ips")

      strings = ["addthis", "admantx", "alexa", "anderspink", "apache-httpclient", "apachebench", "apis-google", "appengine-google", "appsignal", "ask jeeves", "asynchttpclient", "awe.sm", "baidu", "barkrowler", "bingpreview", "bubing", "butterfly", "buzztalk", "check_http", "checkly", "chrome-lighthouse", "cloudflare", "cmradar/0.1", "coldfusion", "comodo ssl checker", "copypants", "crowsnest", "dap/nethttp", "datafeedwatch", "datanyze", "daumoa", "developers.google.com/+/web/snippet/", "digitalpersona fingerprint software", "embedly", "eoaagent", "evrinid", "exaleadcloudview", "ez publish", "facebookexternalhit", "feedburner", "flipboardproxy", "garlik", "genieo", "getprismatic.com", "go http package", "go-http-client", "google page speed insights", "google web preview", "google-site-verification", "google-structured-data-testing-tool", "google-structureddatatestingtool", "google-xrawler", "googleimageproxy", "hatena", "heritrix", "https", "httrack", "hubspot", "ia_archiver", "icoreservice", "idmarch", "inagist", "insieve", "instapaper", "jaunt", "jetslide", "jobseeker", "jooble", "js-kit", "kimengi", "knows.is", "kraken", "laconica", "linode", "lipperhey", "longurl", "ltx71", "mappydata", "mastodon", "mediapartners-google", "megaindex.ru", "metauri", "mfe_expand", "netcraft", "netstate", "netvibes", "newrelicpinger", "newsme", "ning", "nutch", "paessler", "pagesinventory", "panopta", "peerindex", "phantomjs", "pingdom", "pinterest", "plukkie", "pr-cy.ru", "proximic", "pu_in", "publiclibraryarchive.org", "python-httplib2", "python-requests", "python-urllib", "queryseeker", "quicklook", "re-animator", "readability", "rebelmouse", "relateiq", "riddler", "rssmicro", "scrapy", "seo-audit", "seodiver", "seokicks", "shopwiki", "shortlinktranslate", "siege", "sistrix", "sitecheck", "siteuptime", "skypeuripreview", "slack-imgproxy", "slack-linkexpanding", "slack", "slurp", "snapchat", "socialrank", "sogou", "spinn3r", "squider", "statuscake", "teeraid", "test certificate info", "the knowledge ai", "tineye", "traackr", "trendsmap", "tweetedtimes", "twikle", "twitmunin", "twurly", "typhoeus", "updown", "vagabondo", "vb project", "vigil", "vkshare", "watchsumo", "webceo", "webscout", "wesee", "whatsapp", "wikido", "woorank", "wordpress", "wormly", "wotbox", "xenu link sleuth", "xing-contenttabreceiver", "yandex", "yanga", "yeti", "yourls", "zabbix", "zelist.ro", "zibb", "zyborg", "anthropic-ai", "chatgpt-user", "claude-web", "cohere-ai", "google-extended", "googleother", "omgili", "webz.io", "httpie", "eventmachine httpclient", "go 1.1 package http", "htmlparser", "http_request2", "httpclient", "jakarta commons", "java", "libwww-perl", "lwp-trivial", "ruby"]
      strings.sort!
      syms = strings.map(&:to_s)
      dataset_size = strings.length

      Benchmark.ips do |bm|
        i = 0
        set = strings.to_set
        bm.report("sets") do
          assert set.include?(strings[i])

          i = (i + 1) % dataset_size
        end

        i = 0
        hash = strings.map { |it| [it, true] }.to_h
        bm.report("hashes") do
          assert hash.key?(strings[i])

          i = (i + 1) % dataset_size
        end
        i = 0
        set = syms.to_set
        bm.report("sets keys") do
          assert set.include?(syms[i])

          i = (i + 1) % dataset_size
        end

        i = 0
        symhash = syms.map { |it| [it, true] }.to_h
        bm.report("hashes keys") do
          assert symhash.key?(syms[i])

          i = (i + 1) % dataset_size
        end

        bm.compare!
      end
    end

    test "generic matching" do
      skip("Benchmarking libraries are not installed") unless maybe_require("benchmark/ips")

      strings = [
        "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/605.1.16 (KHTML, like Gecko; compatible; Friendly_Crawler/2.0) Chrome/120.0.6099.217 Safari/605.1.15/Nutch-1.20-SNAPSHOT",
        "Mozilla/5.0 (compatible; Alexabot/1.0; +http://www.alexa.com/help/certifyscan; certifyscan@alexa.com)",
      ]
      strings.map!(&:downcase)
      keys = strings.map do |str|
        str.tr("^a-z0-9", " ").split.keep_if { |it| it.length > 3 }
      end
      patterns = ["bot", "crawl", "scan", "spider"]

      Benchmark.ips do |bm|
        match_regex = /bot|crawl|scan|spider/
        bm.report("tr") do
          120.times do |i|
            strings[i % 3].downcase.tr!("^a-z0-9", " ").split
          end
        end

        bm.report("tr_s") do
          120.times do |i|
            strings[i % 3].downcase.tr_s!("^a-z0-9", " ").split
          end
        end

        bm.compare!
      end
    end
  end
end

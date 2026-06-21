module Skadi
  # A minimal user agent parser, designed for speed rather than completeness, aiming to detect the most common browsers
  # and operating systems.
  #
  # Why implement a custom user agent parsing script over an existing library?
  #
  # Firstly, to eliminate the transient dependencies consumers of this gem are exposed to.
  #
  # Secondly, existing libraries have relatively poor performance. Unlike other solutions, which use a large number of
  # regular expressions to detect browsers, this parser tokenises the user agent and uses a lookup table to identify the
  # majority of browsers with O(1) performance, using regular expressions as fallback. See the `user_agent_test.rb` file
  # for performance statistics.
  #
  # Thirdly, the user agent parsing gems are years out of date. Modern browsers and modern bots are not properly
  # detected, potentially skewing the analytics data collected.
  class UserAgent
    def initialize(user_agent)
      @user_agent = user_agent
    end

    def browser
      parse_browser if @browser.nil?

      @browser
    end

    def browser_version
      parse_browser if @browser_version.nil?

      @browser_version
    end

    def engine
      parse_engine if @engine.nil?

      @engine
    end

    def engine_version
      parse_engine if @engine_version.nil?

      @engine_version
    end

    def os
      parse_os if @os.nil?

      @os
    end

    def bot?
      return @bot unless @bot.nil?

      # If the user agent doesn't follow the normal browser patterns, we assume it's a bot
      parse_browser if @browser.nil?
      if @browser == "Unknown"
        @bot = true

        return true
      end

      @bot = detect_bot
    end

    def human? = !bot?

    def to_h
      {
        browser: browser,
        browser_version: browser_version,
        engine: engine,
        engine_version: engine_version,
        os: os,
        bot: bot?
      }
    end

    BROWSER_MATCHERS = [
      {
        regex: /Chrome\/(?<version>\d+).*WebView|; wv.*Chrome\/(?<version>\d+)/,
        browser: "Chrome WebView"
      }.freeze,
      {
        regex: /Android.*Version\/(?<version>\d+)/,
        browser: "Android Browser",
        os: "Android",
      }.freeze,
      {
        regex: /Android.*Chrome\/(?<version>\d+)/,
        browser: "Chrome for Android",
        os: "Android",
      }.freeze,
      {
        regex: /(?:iOS|iPod|iPad|iPhone).*(?:CriOS|Chrome)\/(?<version>\d+)/,
        browser: "Chrome for iOS",
        os: "iOS",
      }.freeze,
      {
        regex: /(?:CriOS|Chrome)\/(?<version>\d+)/,
        browser: "Chrome"
      }.freeze,
      {
        regex: /(?:iOS|iPod|iPad|iPhone).+Version\/(?<version>\d+)/,
        browser: "Safari for iOS",
        os: "iOS",
      }.freeze,
      {
        regex: /GSA\/(?<version>\d+)/,
        browser: "GSA"
      }.freeze,
      {
        regex: /(?:iOS|iPod|iPad|iPhone).*Safari/,
        browser: "Safari for iOS",
        os: "iOS",
      }.freeze,
      {
        regex: /Version\/(?<version>\d+).*Safari/,
        browser: "Safari",
      }.freeze,
      {
        regex: /Safari\//,
        browser: "Safari",
      }.freeze,
      {
        regex: /WebKit\/(?<version>\d+)/,
        browser: "WebKit"
      }.freeze,
      {
        regex: /Mozilla\/(?<version>\d+).*rv:(?<engine_version>\d+).*?Gecko\/\d+/,
        browser: "Mozilla",
        engine: "Gecko",
      }.freeze,
    ].freeze

    BROWSER_TOKENS = {
      "AlohaBrowser" => {
        browser: "Aloha",
      },
      "Avast" => {
        browser: "Avast Secure Browser",
      },
      "AVG" => {
        browser: "AVG Secure Browser",
      },
      "baiduboxapp" => {
        browser: "Baidu",
      },
      "BingSapphire" => {
        browser: "Bing",
      },
      "Brave" => {},
      "Chromium" => {
        regex: /Chromium[\/ ](?<version>GOST|\d+)/,
      },
      "Ddg" => {
        browser: "DuckDuckGo",
      },
      "DuckDuckGo" => {},
      "Ecosia" => {
        regex: /Ecosia ios@(?<version>\d+)/,
        os: "iOS",
      },
      "Edg" => [
        {
          regex: /(?:iOS|iPod|iPad|iPhone).*Edg\/(?<version>\d+)/,
          browser: "Edge for iOS",
          os: "iOS",
        },
        {
          regex: /Android.*Edg\/(?<version>\d+)/,
          browser: "Edge for Android",
          os: "Android",
        },
        {
          regex: /Edg\/(?<version>\d+)/,
          browser: "Edge",
        },
      ],
      "EdgA" => {
        browser: "Edge for Android",
        os: "Android",
      },
      "Edge" => {},
      "EdgiOS" => {
        browser: "Edge for iOS",
        os: "iOS",
      },
      "Electron" => {},
      "FBAV" => {
        browser: "Facebook",
      },
      "Firefox" => [
        {
          regex: /(?<browser>PaleMoon|Waterfox)\/(?<version>\d+)/,
        }.freeze,
        {
          regex: /(?:iOS|iPod|iPad|iPhone).*Firefox\/(?<version>\d+)/,
          browser: "Firefox for iOS",
          os: "iOS",
        }.freeze,
        {
          regex: /Android.*Firefox\/(?<version>\d+)/,
          browser: "Firefox for Android",
          os: "Android",
        }.freeze,
        {
          regex: /Firefox\/(?<version>\d+)/,
          browser: "Firefox"
        }.freeze,
      ],
      "FxiOS" => {
        browser: "Firefox for iOS",
      },
      "HeadlessChrome" => {
        browser: "Chrome Headless",
      },
      "HeyTapBrowser" => {
        browser: "HeyTap",
      },
      "HuaweiBrowser" => {
        browser: "Huawei Browser",
      },
      "Instagram" => {
        regex: /Instagram[\/ ](?<version>\d+)/,
      },
      "Iron" => {
        regex: /Chrome\/(?<version>\d+).*?Iron/,
      },
      "KAKAOTALK" => {
        regex: /KAKAOTALK[\/ ](?<version>\d+)/,
      },
      "Konqueror" => {},
      "Line" => {},
      "LinkedInApp" => {
        regex: /\[LinkedInApp\]\/(?<version>\d+)/,
        browser: "LinkedIn",
      },
      "Maxthon" => {},
      "MicroMessenger" => {
        browser: "WeChat",
      },
      "MiuiBrowser" => {
        browser: "MIUI Browser",
      },
      "MQQBrowser" => {},
      "MSIE" => {
        regex: /MSIE (?<version>\d+)(?:.*(?<engine>Trident)\/(?<engine_version>\d+))?|(?<engine>Trident)\/(?<engine_version>\d+).*rv[: ](?<version>\d+)/,
        browser: "IE",
        os: "Windows",
      }.freeze,
      "musical" => {
        regex: /musical_ly_(?<version>\d+)/,
        browser: "TikTok",
      },
      "Norton" => {
        browser: "Norton Private Browser",
      },
      "OculusBrowser" => {
        browser: "Oculus Browser",
      },
      "Opera" => {
        regex: /(?<browser>Opera Mini)[\/ ](?<version>\d+)|(?<browser>Opera)(?!.*Mini)(.*Version)?[\/ ](?<version>\d+)/,
      },
      "OPR" => {
        browser: "Opera",
      },
      "OPT" => {
        browser: "Opera Touch",
      },
      "OPX" => {
        browser: "Opera GX",
      },
      "PaleMoon" => {},
      "QQBrowser" => {},
      "QuarkPC" => {
        browser: "Quark",
      },
      "SamsungBrowser" => {
        browser: "Samsung Internet",
      },
      "SeaMonkey" => {},
      "Silk" => {},
      "Snapchat" => {},
      "TikTokLIVEStudio" => {},
      "Trident" => {
        regex: /MSIE (?<version>\d+).*Trident\/(?<engine_version>\d+)|Trident\/(?<engine_version>\d+).*rv[: ](?<version>\d+)/,
        browser: "IE",
        engine: "Trident",
        os: "Windows",
      }.freeze,
      "Twitter" => {
        regex: /Twitter for iPhone\/(?<version>\d+)/,
      },
      "UCBrowser" => {},
      "VivoBrowser" => {
        browser: "Vivo Browser",
      },
      "Whale" => {},
      "YaBrowser" => {
        browser: "Yandex",
      },
      "YaSearchBrowser" => {
        browser: "Yandex",
      },
    }.each_pair do |key, options|
      next unless options.is_a?(Hash)

      options[:regex] ||= /#{key}\/(?<version>\d+)/
      options[:browser] ||= key
    end

    private def parse_browser
      # First we check if any of the UA tokens exist as keys to our browser token list (fast!)
      user_agent_tokens.each do |token|
        next unless BROWSER_TOKENS.key?(token)

        # We then use the matcher to extract the version from the full user agent
        matchers = if !BROWSER_TOKENS[token].is_a?(Array)
          [BROWSER_TOKENS[token]]
        else
          BROWSER_TOKENS[token]
        end

        matchers.each do |matcher|
          return if run_matcher(matcher)
        end
      end

      # Then, if we don't get a match, we run the full list of fallback matchers against the user agent (slow!)
      BROWSER_MATCHERS.each do |matcher|
        return if run_matcher(matcher)
      end

      # Finally, falling back to unknown values for the browser variables
      @browser = "Unknown"
      @browser_version = "Unknown"
    end

    # Runs a matcher hash against the user agent, srtting relevant instance variables. Returns true if a match was found.
    private def run_matcher(matcher)
      match = matcher[:regex].match(@user_agent)

      if match
        named_captures = match.named_captures

        @browser = named_captures["browser"] || matcher[:browser] || "Unknown"
        @browser_version = named_captures["version"] || matcher[:browser_version] || "Unknown"
        @engine = named_captures["engine"] || matcher[:engine]
        @engine_version = named_captures["engine_version"]
        @os = named_captures["os"] || matcher[:os]

        return true
      end

      false
    end

    ENGINE_MATCHERS = [
      {
        regex: /AppleWebKit\/537\.36.*Edge\/(?<version>1[2-8])\./,
        engine: "EdgeHTML",
      },
      {
        regex: /AppleWebKit\/537\.36.*Chrome\/(?<version>\d+)/,
        engine: "Blink",
      }.freeze,
      {
        regex: /(?<engine>WebKit|Presto|Trident|Goanna)\/(?<version>\d+)/,
      }.freeze,
      {
        regex: /rv:(?<version>\d+).*?Gecko\/\d+/,
        engine: "Gecko",
      }.freeze,
    ].freeze

    private def parse_engine
      # Since there are only 4 engine matchers, there is little performance to be gained by using the token approach to parsing
      ENGINE_MATCHERS.each do |matcher|
        match = matcher[:regex].match(@user_agent)

        if match
          named_captures = match.named_captures

          @engine = named_captures["engine"] || matcher[:engine] || "Unknown"
          @engine_version = named_captures["version"] || "Unknown"

          return
        end
      end

      @engine = "Unknown"
      @engine_version = "Unknown"
    end


    OS_TOKENS = {
      "CFNetwork" => "iOS",
      "CrOS" => "Chrome OS",
      "Fedora" => "Fedora",
      "Gentoo" => "Gentoo",
      "HarmonyOS" => "HarmonyOS",
      "iPad" => "iOS",
      "iPhone" => "iOS",
      "iPod" => "iOS",
      "Mac" => "macOS",
      "Ubuntu" => "Ubuntu",
      "Windows" => "Windows",
    }

    private def parse_os
      linux_fallback = false
      android_fallback = false
      user_agent_tokens.each do |token|
        if OS_TOKENS.key?(token)
          @os = OS_TOKENS[token]

          return
        end

        android_fallback ||= token == "Android"
        linux_fallback ||= token == "Linux"
      end

      # HarmonyOS UAs can contain Android, and Android UAs can contain "Linux" so we need to do these in a specific order
      @os ||= "Android" if android_fallback
      @os ||= "Linux" if linux_fallback
      @os ||= "Unknown"
    end

    BOT_GLOBAL_MATCHERS = %w[bot crawl scan spider].freeze

    BOT_WORD_SET = Set.new(%w[AGENT Agent AppInsights ArchiveBox Archiver Archiving BingPreview BrandVerity Butterfly Charlotte Checkly Claude CloudFlare Cloudflare Code Collapsify CookieHubVerify Criticalcss Daily DareBoost DatadogSynthetics Datanyze Devin Dlc FeedBurner Feeder Feedly FlipboardProxy Fluid Foregenix GTmetrix GeedoProductSearch GeedoShopProductFinder Google GoogleAgent GoogleImageProxy GotSiteMonitor Hardenize HeadlessChrome Hotjar Inspector Lighthouse LinkTiger Mail Manus MarketGoo MarketingMiner MetaIAB Miniature MonitoRSS Monitor Netcraft NewRelicSynthetics NewsBlur NewsNow Newsify Nitro OpenGraph Optimizer PTST PWABuilderHttpAgent Perplexity PingdomTMS Playwright Preview PrintFriendly Puppeteer Readable RevvimGort Rigor SQWatcher Scope3 SecurityHeaders Selenium SeoSiteCheckup Silktide Sindup Siteimprove Specificfeeds Sucuri TestLocally ThousandEyes Trae YLT ZoteroTranslationServer adbeat agent archiver archiving brandverity butterfly claude cloudflare code contentkingapp deadlinkchecker devin europarchive feeder feedly google img2dataset infegy mail mailservertest2023 marketingminer mirrorweb monitor nbertaupete95 netcraft newsai newsblur newsify opencode opengraph oupwis perplexity preview retrevo scope3 scraping seositecheckup sitebulb slider splash sqwatcher turingos ubermetrics uptimedoctor watchTowr webresearch websitepulse woorankreview xmco]).freeze

    BOT_FALLBACK_MATCHERS = ["AP3A.240617.008"].freeze

    private def detect_bot
      return true if user_agent_tokens.any? { |it| BOT_WORD_SET.include? it }

      user_agent_downcase = @user_agent.downcase
      return true if BOT_GLOBAL_MATCHERS.any? { |it| user_agent_downcase.include? it }

      return true if BOT_FALLBACK_MATCHERS.any? { |it| @user_agent.include? it }

      false
    end

    # Splits the string into alphanumeric sequences of length 3 or more
    private def user_agent_tokens
      @user_agent_tokens ||= @user_agent.tr("^a-zA-Z0-9", " ").split.keep_if { |it| it.length >= 3 }
    end
  end
end

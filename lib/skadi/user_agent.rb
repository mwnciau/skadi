module Skadi
  # A minimal user agent parser, designed for speed rather than completeness, aiming to detect the most common browsers and operating systems.
  # See https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Browser_detection_using_the_user_agent
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
      "avast" => {
        regex: /Avast\/(?<version>\d+)/,
        browser: "Avast Secure Browser",
      },
      "avg" => {
        regex: /AVG\/(?<version>\d+)/,
        browser: "AVG Secure Browser",
      },
      "baiduboxapp" => {
        regex: /baiduboxapp\/(?<version>\d+)/,
        browser: "Baidu",
      },
      "bingsapphire" => {
        regex: /BingSapphire\/(?<version>\d+)/,
        browser: "Bing",
      },
      "brave" => "Brave",
      "chromium" => {
        regex: /Chromium[\/ ](?<version>GOST|\d+)/,
        browser: "Chromium",
      }.freeze,
      "ddg" => {
        regex: /Ddg\/(?<version>\d+)/,
        browser: "DuckDuckGo",
      },
      "duckduckgo" => "DuckDuckGo",
      "ecosia" => {
        regex: /Ecosia ios@(?<version>\d+)/,
        browser: "Ecosia",
        os: "iOS",
      },
      "edg" => [
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
      "edga" => {
        regex: /EdgA\/(?<version>\d+)/,
        browser: "Edge for Android",
        os: "Android",
      },
      "edge" => "Edge",
      "edgios" => {
        regex: /EdgiOS\/(?<version>\d+)/,
        browser: "Edge for iOS",
        os: "iOS",
      },
      "electron" => "Electron",
      "fbav" => {
        regex: /FBAV\/(?<version>\d+)/,
        browser: "Facebook",
      },
      "firefox" => [
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
      "fxios" => {
        regex: /FxiOS\/(?<version>\d+)/,
        browser: "Firefox for iOS",
      },
      "headlesschrome" => {
        regex: /HeadlessChrome\/(?<version>\d+)/,
        browser: "Chrome Headless",
      },
      "heytapbrowser" => {
        regex: /HeyTapBrowser\/(?<version>\d+)/,
        browser: "HeyTap",
      },
      "huaweibrowser" => {
        regex: /HuaweiBrowser\/(?<version>\d+)/,
        browser: "Huawei Browser",
      },
      "instagram" => "Instagram",
      "kakaotalk" => {
        regex: /KAKAOTALK[\/ ](?<version>\d+)/,
        browser: "KAKAOTALK",
      },
      "konqueror" => "Konqueror",
      "line" => "Line",
      "linkedinapp" => {
        regex: /\[LinkedInApp\]\/(?<version>\d+)/,
        browser: "LinkedIn",
      },
      "maxthon" => "Maxthon",
      "micromessenger" => {
        regex: /MicroMessenger\/(?<version>\d+)/,
        browser: "WeChat",
      },
      "miuibrowser" => {
        regex: /MiuiBrowser\/(?<version>\d+)/,
        browser: "MIUI Browser",
      },
      "mqqbrowser" => "MQQBrowser",
      "msie" => {
        regex: /MSIE (?<version>\d+)(?:.*(?<engine>Trident)\/(?<engine_version>\d+))?|(?<engine>Trident)\/(?<engine_version>\d+).*rv[: ](?<version>\d+)/,
        browser: "IE",
        os: "Windows",
      }.freeze,
      "musical" => {
        regex: /musical_ly_(?<version>\d+)/,
        browser: "TikTok",
      },
      "norton" => {
        regex: /Norton\/(?<version>\d+)/,
        browser: "Norton Private Browser",
      },
      "opera" => {
        regex: /(?<browser>Opera Mini)[\/ ](?<version>\d+)|(?<browser>Opera)(?!.*Mini)(.*Version)?[\/ ](?<version>\d+)/,
      },
      "opr" => {
        regex: /OPR\/(?<version>\d+)/,
        browser: "Opera",
      },
      "opt" => {
        regex: /OPT\/(?<version>\d+)/,
        browser: "Opera Touch",
      },
      "opx" => {
        regex: /OPX\/(?<version>\d+)/,
        browser: "Opera GX",
      },
      "palemoon" => "PaleMoon",
      "qqbrowser" => "QQBrowser",
      "quarkpc" => {
        regex: /QuarkPC\/(?<version>\d+)/,
        browser: "Quark",
      },
      "samsungbrowser" => {
        regex: /SamsungBrowser\/(?<version>\d+)/,
        browser: "Samsung Internet",
      },
      "seamonkey" => "SeaMonkey",
      "silk" => "Silk",
      "snapchat" => "Snapchat",
      "tiktoklivestudio" => "TikTokLIVEStudio",
      "trident" => {
        regex: /MSIE (?<version>\d+).*Trident\/(?<engine_version>\d+)|Trident\/(?<engine_version>\d+).*rv[: ](?<version>\d+)/,
        browser: "IE",
        engine: "Trident",
        os: "Windows",
      }.freeze,
      "twitter" => {
        regex: /Twitter for iPhone\/(?<version>\d+)/,
        browser: "Twitter",
      },
      "ucbrowser" => "UCBrowser",
      "vivobrowser" => {
        regex: /VivoBrowser\/(?<version>\d+)/,
        browser: "Vivo Browser",
      },
      "whale" => "Whale",
      "yabrowser" => {
        regex: /YaBrowser\/(?<version>\d+)/,
        browser: "Yandex",
      },
    }

    private def parse_browser
      user_agent_tokens.each do |token|
        next unless BROWSER_TOKENS.key?(token)

        matchers = BROWSER_TOKENS[token]
        matchers = if matchers.is_a?(String)
          [{
            regex: /#{matchers}[\/ ](?<version>\d+)/,
            browser: matchers,
          }]
        elsif !matchers.is_a?(Array)
          [matchers]
        else
          matchers
        end

        matchers.each do |matcher|
          return if run_matcher(matcher)
        end
      end

      BROWSER_MATCHERS.each do |matcher|
        return if run_matcher(matcher)
      end

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
      ENGINE_MATCHERS.each do |matcher|
        match = matcher[:regex].match(@user_agent)

        if match
          named_captures = match.named_captures

          @engine = matcher[:engine] || named_captures["engine"] || "Unknown"
          @engine_version = named_captures["version"] || "Unknown"

          return
        end
      end

      @engine = "Unknown"
      @engine_version = "Unknown"
    end


    OS_MATCHERS = [
      {
        regex: /(?<os>HarmonyOS|Windows)/,
      }.freeze,
      {
        regex: /iPod|iPad|iPhone|CFNetwork/,
        os: "iOS",
      }.freeze,
      {
        regex: /Android/,
        os: "Android",
      }.freeze,
      {
        regex: /Mac OS/,
        os: "macOS",
      }.freeze,
      {
        regex: /(?<os>Fedora|Ubuntu)/,
      }.freeze,
      {
        regex: /Linux/,
        os: "Linux",
      }.freeze,
      {
        regex: /CrOS/,
        os: "Chrome OS",
      }.freeze,
    ].freeze

    private def parse_os
      OS_MATCHERS.each do |matcher|
        match = matcher[:regex].match(@user_agent)

        if match
          if matcher.key?(:os)
            @os = matcher[:os]
            return
          end

          @os = match.named_captures["os"] || "Unknown"
          return
        end
      end

      @os = "Unknown"
    end

    BOT_GLOBAL_MATCHERS = %w[bot crawl scan spider].freeze

    BOT_WORD_SET = Set.new(%w[adbeat agent appinsights archivebox archiver archiving bingpreview brandverity butterfly charlotte checkly cloudflare claude code collapsify contentkingapp cookiehubverify criticalcss dareboost datadogsynthetics datanyze deadlinkchecker devin dlc europarchive feedburner feeder feedly flipboardproxy fluid foregenix geedoproductsearch geedoshopproductfinder google googleagent googleimageproxy gotsitemonitor gtmetrix hardenize headlesschrome hotjar img2dataset infegy inspector lighthouse linktiger mail mailservertest2023 manus marketgoo marketingminer metaiab miniature mirrorweb monitor monitorss nbertaupete95 netcraft newrelicsynthetics newsai newsblur newsify newsnow nitro opencode opengraph optimizer oupwis perplexity pingdomtms playwright printfriendly ptst puppeteer pwabuilderhttpagent readable retrevo revvimgort rigor scope3 scraping securityheaders selenium seositecheckup slider splash silktide sindup sitebulb siteimprove specificfeeds sqwatcher sucuri testlocally thousandeyes trae turingos ubermetrics uptimedoctor watchtowr webresearch websitepulse woorankreview xmco zoterotranslationserver]).freeze

    BOT_FALLBACK_MATCHERS = ["AP3A.240617.008", "page-preview-tool", "PS_Daily", "YLT Chrome"].freeze

    private def detect_bot
      return true if user_agent_tokens.any? { |it| BOT_WORD_SET.include? it }

      ua = user_agent_downcase
      return true if BOT_GLOBAL_MATCHERS.any? { |it| ua.include? it }

      return true if BOT_FALLBACK_MATCHERS.any? { |it| @user_agent.include? it }

      false
    end

    private def user_agent_downcase
      @user_agent_downcase ||= @user_agent.downcase
    end

    private def user_agent_tokens
      return @user_agent_tokens unless @user_agent_tokens.nil?

      @user_agent_tokens = user_agent_downcase.tr("^a-z0-9", " ").split.keep_if { |it| it.length >= 3 }
    end
  end
end

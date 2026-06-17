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

      @bot = self.class.bot_fast?(@user_agent)
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
        regex: %r{
          (?<browser>
            baiduboxapp
            | FBAV
            | HuaweiBrowser
            | MicroMessenger
            | musical_ly
            | OP[RTX]
            | VivoBrowser
          )[\/_](?<version>\d+)
        }x,
      }.freeze,
      {
        regex: /Chrome\/(?<version>\d+).*WebView|; wv.*Chrome\/(?<version>\d+)/,
        browser: "Chrome WebView"
      }.freeze,
      {
        regex: %r{
          (?<browser>
            Avast
            | AVG
            | BingSapphire
            | Brave
            | Ddg | DuckDuckGo
            | Ecosia\ ios
            | Electron
            | HeadlessChrome
            | Instagram
            | Line
            | Maxthon
            | MiuiBrowser
            | Norton
            | Opera\ Mini
            | PaleMoon
            | QQBrowser
            | SamsungBrowser
            | SeaMonkey
            | Silk
            | Snapchat
            | Twitter\ for\ iPhone
            | UCBrowser
            | Waterfox
            | Whale
            | YaBrowser
          )[\/@\ ](?<version>\d+)
        }x,
      }.freeze,
      {
        regex: /Opera(.*Version\/)?(?<version>\d+)/,
        browser: "Opera"
      }.freeze,
      {
        regex: /Android.*Version\/(?<version>\d+)/,
        browser: "Android Browser",
        os: "Android",
      }.freeze,
      {
        regex: /Edg.?(?:OS)?\/(?<version>\d+)/,
        browser: "Edge"
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
        regex: /Chromium GOST/,
        browser: "Chromium",
        browser_version: "GOST",
      }.freeze,
      {
        regex: /(?:CriOS|Chrome)\/(?<version>\d+)/,
        browser: "Chrome"
      }.freeze,
      {
        regex: /(?:iOS|iPod|iPad|iPhone).*Firefox\/(?<version>\d+)|FxiOS\/(?<version>\d+)/,
        browser: "Firefox for iOS",
        os: "iOS",
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
        browser_version: "1",
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
      {
        regex: /(?<browser>LinkedIn)/,
      }.freeze,
      {
        regex: /WebKit\/(?<version>\d+)/,
        browser: "WebKit"
      }.freeze,
      {
        regex: /MSIE (?<version>\d+).*Trident\/(?<engine_version>\d+)|Trident\/(?<engine_version>\d+).*rv:(?<version>\d+)/,
        browser: "IE",
        engine: "Trident",
        os: "Windows",
      }.freeze,
      {
        regex: /Mozilla\/(?<version>\d+).*rv:(?<engine_version>\d+).*?Gecko\/\d+/,
        browser: "Mozilla",
        engine: "Gecko",
      }.freeze,
    ].freeze

    # Normalise the name of the browser for browsers that are detected in a larger regex
    BROWSER_NAME_REMAP = {
      "Avast" => "Avast Secure Browser",
      "AVG" => "AVG Secure Browser",
      "baiduboxapp" => "Baidu",
      "BingSapphire" => "Bing",
      "HeadlessChrome" => "Chrome Headless",
      "Ddg" => "DuckDuckGo",
      "Ecosia ios" => "Ecosia",
      "FBAV" => "Facebook",
      "HuaweiBrowser" => "Huawei Browser",
      "MicroMessenger" => "WeChat",
      "MiuiBrowser" => "MIUI Browser",
      "musical_ly" => "TikTok",
      "Norton" => "Norton Private Browser",
      "OPR" => "Opera",
      "OPT" => "Opera Touch",
      "OPX" => "Opera GX",
      "SamsungBrowser" => "Samsung Internet",
      "Twitter for iPhone" => "Twitter",
      "VivoBrowser" => "Vivo Browser",
      "YaBrowser" => "Yandex",
    }.freeze

    private def parse_browser
      BROWSER_MATCHERS.each do |matcher|
        match = matcher[:regex].match(@user_agent)

        if match
          named_captures = match.named_captures

          @browser = matcher[:browser] || BROWSER_NAME_REMAP[named_captures["browser"]] || named_captures["browser"] || "Unknown"
          @browser_version = matcher[:browser_version] || named_captures["version"] || "Unknown"
          @engine = matcher[:engine] if matcher[:engine].present?
          @engine_version = named_captures["engine_version"]
          @os = named_captures["os"]

          return
        end
      end

      @browser = "Unknown"
      @browser_version = "Unknown"
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
        regex: /(?<os>Linux|Fedora|Ubuntu)/,
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
    BOT_WORD_SET = Set.new(%w[adbeat agent appinsights archivebox archiver archiving bingpreview brandverity butterfly charlotte checkly cloudflare claude code collapsify contentkingapp cookiehubverify criticalcss dareboost datadogsynthetics datanyze deadlinkchecker devin feedburner feeder feedly flipboardproxy fluid foregenix geedoproductsearch google googleagent googleimageproxy gotsitemonitor gtmetrix hardenize headlesschrome hotjar img2dataset infegy inspector lighthouse linktiger mail mailservertest2023 manus marketgoo marketingminer metaiab miniature mirrorweb monitor monitorss nbertaupete95 newrelicsynthetics newsai newsblur newsify nitro opencode opengraph optimizer oupwis perplexity pingdomtms playwright printfriendly ptst puppeteer pwabuilderhttpagent readable revvimgort rigor scope3 scraping securityheaders selenium seositecheckup slider splash silktide sindup sitebulb siteimprove specificfeeds sqwatcher sucuri testlocally thousandeyes trae turingos ubermetrics uptimedoctor watchtowr webresearch woorankreview xmco zoterotranslationserver]).freeze
    BOT_FALLBACK_MATCHERS = ["AP3A.240617.008", "Dlc/", "page-preview-tool", "PS_Daily", "YLT Chrome"].freeze

    def self.bot_fast?(user_agent)
      ua = user_agent.downcase
      return true if BOT_GLOBAL_MATCHERS.any? { |it| ua.include? it }

      ua.tr!("^a-z0-9", " ")
      ua_keys = ua.split.keep_if { |it| it.length > 3 }
      return true if ua_keys.any? { |it| BOT_WORD_SET.include? it }

      return true if BOT_FALLBACK_MATCHERS.any? { |it| user_agent.include? it }

      return false
    end
  end
end

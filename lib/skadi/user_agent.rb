module Skadi
  # A minimal user agent parser, designed for speed rather than completeness, aiming to detect the most common browsers and operating systems.
  # See https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Browser_detection_using_the_user_agent
  module UserAgent
    def self.parse(user_agent)
      result = parse_browser(user_agent)

      result.merge!(parse_engine(user_agent)) unless result.key?(:engine) && result.key?(:engine_version)
      result.merge!(parse_os(user_agent)) unless result.key?(:os)

      result
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

    def self.parse_browser(user_agent)
      BROWSER_MATCHERS.each do |matcher|
        match = matcher[:regex].match(user_agent)

        if match
          result = matcher.except(:regex)
          named_captures = match.named_captures
          result[:browser] ||= named_captures["browser"] if named_captures["browser"].present?
          result[:browser] = BROWSER_NAME_REMAP[result[:browser]] || result[:browser] || "Unknown"

          result[:browser_version] ||= named_captures["version"] if named_captures["version"].present?
          result[:browser_version] ||= "Unknown"

          result[:engine_version] ||= named_captures["engine_version"] if named_captures["engine_version"].present?

          result[:os] ||= named_captures["os"] if named_captures["os"].present?

          return result
        end
      end

      { browser: "Unknown", browser_version: "Unknown" }
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

    def self.parse_engine(user_agent)
      ENGINE_MATCHERS.each do |matcher|
        match = matcher[:regex].match(user_agent)

        if match
          result = matcher.except(:regex)
          named_captures = match.named_captures
          result[:engine] ||= named_captures["engine"] if named_captures["engine"].present?
          result[:engine_version] ||= named_captures["version"] if named_captures["version"].present?

          return result
        end
      end

      { engine: "Unknown", engine_version: "Unknown" }
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

    def self.parse_os(user_agent)
      OS_MATCHERS.each do |matcher|
        match = matcher[:regex].match(user_agent)

        if match
          return {os: matcher[:os]} if matcher.key?(:os)

          named_captures = match.named_captures
          return {os: named_captures["os"]} if named_captures["os"].present?
        end
      end

      return { os: "Unknown" }
    end

    BOT_MATCHER = %r{
      bot
      | crawl
      | spider
    }ix

    def self.bot?(user_agent)
      false
    end
  end
end

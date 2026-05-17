Gem::Specification.new do |s|
  s.name = "skadi"
  s.version = "0.0.0"
  s.summary = "First-party, privacy-by-default analytics for Rails."
  s.description = "Skadi adds flexible and lightweight first-party analytics to your Rails app. Track page views and events, perform A/B testing and more, giving you all the information you need to improve your website."
  s.authors = ["Simon J"]
  s.email = "2857218+mwnciau@users.noreply.github.com"
  s.files = [
    "lib/skadi.rb",
    "CHANGELOG.md",
    "LICENSE.md",
    "README.md",
  ]
  s.require_paths = ["lib"]
  s.homepage = "https://rubygems.org/gems/skadi"
  s.metadata = {
    "source_code_uri" => "https://github.com/mwnciau/skadi",
    "changelog_uri" => "https://github.com/mwnciau/skadi/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://github.com/mwnciau/skadi",
    "bug_tracker_uri" => "https://github.com/mwnciau/skadi/issues",
  }

  s.license = "MIT"
  s.required_ruby_version = ">= 2.0.0"

  s.add_development_dependency "minitest", "~> 6.0"
  s.add_development_dependency "standard", "~> 1.0"
  s.add_development_dependency "rubocop", "~> 1.0"
end

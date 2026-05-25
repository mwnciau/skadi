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
  s.required_ruby_version = ">= 3.3.0"

  s.post_install_message = <<~MSG
    Thanks for installing Skadi!

    To finish setup, run:

        rails generate skadi:install
        rails db:migrate

    See `rails g skadi:install --help` for options (database engine, user id type).
  MSG
  
  s.add_dependency "rails", ">=7"

  # Gems to enhance testing
  s.add_development_dependency "minitest", "~> 6.0"
  s.add_development_dependency "factory_bot_rails", "~> 6.0"

  # Gems to enforce coding-standards
  s.add_development_dependency "rubocop", "~> 1.0"
  s.add_development_dependency "standard", "~> 1.0"

  # Database gem for the dummy rails app
  s.add_development_dependency "sqlite3", "~> 2.0"
end

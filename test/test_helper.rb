$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rails"
require "active_record"
require "rails/generators"
require "rails/generators/test_case"

require "minitest/autorun"

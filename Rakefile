require "bundler/setup"

# Gem packaging tasks: rake build / install / release
require "bundler/gem_tasks"

# Setup minitest and the `test` task
require "minitest/test_task"
Minitest::TestTask.create

# Set `test` as the default task
task default: ["test"]

# Expose the dummy app's Rake tasks (db:migrate, app:*, etc.) from the engine root
APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

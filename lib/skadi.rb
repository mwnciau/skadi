require "active_support"
require "active_support/concern"
require "active_support/core_ext"

require "action_dispatch/http/request"

require_relative "skadi/anonymity_set"
require_relative "skadi/analytics"
require_relative "skadi/configuration"
require_relative "skadi/engine"
require_relative "skadi/url"
require_relative "skadi/user_agent"

module Skadi
  VERSION = "0.2.0"

  # @return [Skadi::Configuration] The Skadi configuration
  mattr_accessor :configuration, default: Configuration.new

  # @yieldparam config [Skadi::Configuration]
  # @return [void]
  def self.configure
    yield(configuration)
  end
end

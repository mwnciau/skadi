require "active_support"
require "active_support/concern"
require "active_support/core_ext"

require "action_dispatch/http/request"

require_relative "skadi/analytics"
require_relative "skadi/configuration"

module Skadi
  # @return [Skadi::Configuration] The Skadi configuration
  mattr_accessor :configuration, default: Configuration.new

  # @yieldparam config [Skadi::Configuration]
  # @return [void]
  def self.configure
    yield(configuration)
  end
end

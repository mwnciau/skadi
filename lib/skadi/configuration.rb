module Skadi::Configuration
  class Error < StandardError; end

  def initialize
    @use_anonymisation_sets = true
    @anonymisation_set_duration = 1.day
    @anonymisation_set_reset_hour = 3

    @user_method = nil
  end

  # An anonymisation set is a token keeps track of a user using a hash of their IP address and User Agent. A
  # cryptographic pepper is added to the hash, which, when discarded, makes the generated token no longer able to
  # be used to track the user. If disabled, views and events will not be linked to a visitor unless a tracking cookie
  # is set. Defaults to true.
  # @return [Boolean]
  attr_accessor :use_anonymisation_sets

  # How long an anonymisation set should last before expiring. Defaults to 1 day.
  # @return [ActiveSupport::Duration]
  attr_accessor :anonymisation_set_duration

  # Set the hour of the day to reset the anonymisation set. Set to false to strictly use the set duration. Defaults to 3 (3am).
  # @return [Integer, false]
  attr_accessor :anonymisation_set_reset_hour

  # Method to call within controllers to get the current user.
  # @return [Symbol, nil]
  attr_accessor :user_method
end

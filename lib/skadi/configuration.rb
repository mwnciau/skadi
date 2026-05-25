module Skadi
  class Configuration
    class Error < StandardError; end

    def initialize
      @use_anonymisation_sets = true
      @anonymisation_set_duration = 1.day
      @anonymisation_set_reset_hour = 3

      @visit_duration = 2.hours

      @user_method = nil
      @user_model = nil

      @use_query_param_whitelist = true
      @query_param_whitelist = []

      @db_connects_to = nil

      @store_domain_in_views = false
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

    # How long a visit should last before expiring. Note: visits that cross anonymisation set boundaries will be counted as two visits. Defaults to 2 hours.
    # @return [ActiveSupport::Duration]
    attr_accessor :visit_duration

    # The parent app's User class, used to link visits to users
    # @return [Class, nil]
    attr_accessor :user_model

    # Method to call within controllers to get the current user.
    # @return [Symbol, nil]
    attr_accessor :user_method

    # Enable filtering of query parameters to prevent sensitive data being exposed. Defaults to true.
    # @return [Boolean]
    attr_accessor :use_query_param_whitelist

    # An array of query parameter keys to whitelist for storage in URLs.
    # @return [Array<Symbol>]
    attr_accessor :query_param_whitelist

    # The database connection to use for Skadi models
    # @see ActiveRecord::ConnectionHandling.connects_to
    # @return [Hash]
    attr_accessor :db_connects_to

    # Whether to store the domain when tracking views. Can be useful when using multiple domains or subdomains. Defaults to false.
    # @return [Boolean]
    attr_accessor :store_domain_in_views
  end
end

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

      @max_tracking_payload_size = 1024 * 5

      @cookie_domain = nil
    end

    cattr_accessor :validators
    self.validators = {}

    def self.validates(attribute, expecting, &block)
      validators[attribute] = {expecting: expecting, validator: block}
    end

    # An anonymisation set is a token keeps track of a user using a hash of their IP address and User Agent. A
    # cryptographic pepper is added to the hash, which, when discarded, makes the generated token no longer able to
    # be used to track the user. If disabled, views and events will not be linked to a visitor unless a tracking cookie
    # is set. Defaults to true.
    # @return [Boolean]
    attr_accessor :use_anonymisation_sets
    validates(:use_anonymisation_sets, "boolean") { it == true || it == false }

    # How long an anonymisation set should last before expiring. Defaults to 1 day.
    # @return [ActiveSupport::Duration]
    attr_accessor :anonymisation_set_duration
    validates(:anonymisation_set_duration, "ActiveSupport::Duration") { it.is_a?(ActiveSupport::Duration) }

    # Set the hour of the day to reset the anonymisation set. Set to false to strictly use the set duration. Defaults to 3 (3am).
    # @return [Integer, false]
    attr_accessor :anonymisation_set_reset_hour
    validates(:anonymisation_set_reset_hour, "Integer or false") do
      next true if it == false

      it.is_a?(Integer) && it >= 0 && it <= 23
    end

    # How long a visit should last before expiring. Note: visits that cross anonymisation set boundaries will be counted as two visits. Defaults to 2 hours.
    # @return [ActiveSupport::Duration]
    attr_accessor :visit_duration
    validates(:visit_duration, "ActiveSupport::Duration") { it.is_a?(ActiveSupport::Duration) }

    # The parent app's User class, used to link visits to users
    # @return [Class, nil]
    attr_accessor :user_model
    validates(:user_model, "Class or nil") { it.nil? || (it.is_a?(Class) && it < ActiveRecord::Base) }

    # Method to call within controllers to get the current user.
    # @return [Symbol, nil]
    attr_accessor :user_method
    validates(:user_method, "Symbol or nil") { it.nil? || it.is_a?(Symbol) }

    # Enable filtering of query parameters to prevent sensitive data being exposed. Defaults to true.
    # @return [Boolean]
    attr_accessor :use_query_param_whitelist
    validates(:use_query_param_whitelist, "boolean") { it == true || it == false }

    # An array of query parameter keys to whitelist for storage in URLs.
    # @return [Array<Symbol>]
    attr_accessor :query_param_whitelist
    validates(:query_param_whitelist, "Array<Symbol>") { it.is_a?(Array) && it.all? { |key| key.is_a?(Symbol) } }

    # The database connection to use for Skadi models
    # @see ActiveRecord::ConnectionHandling.connects_to
    # @return [Hash, nil]
    attr_accessor :db_connects_to
    validates(:db_connects_to, "Hash compatible with ActiveRecord::ConnectionHandling#connects_to") do
      next true if it.nil?

      it.is_a?(Hash) && !it.empty? && it.keys.all? { |key| [:database, :shards].include?(key) }
    end

    # Whether to store the domain when tracking views. Can be useful when using multiple domains or subdomains. Defaults to false.
    # @return [Boolean]
    attr_accessor :store_domain_in_views
    validates(:store_domain_in_views, "boolean") { it == true || it == false }

    # Sets a limit on the size of the tracking beacon. Defaults to 5KB.
    # @return [Integer]
    attr_accessor :max_tracking_payload_size
    validates(:max_tracking_payload_size, "integer") { it.is_a?(Integer) && it > 0 }

    # The domain to use when setting cookies. Set to include subdomains. Defaults to nil, which will not specify a domain when setting a cookie.
    # @return [String, nil]
    attr_accessor :cookie_domain
    validates(:cookie_domain, "string or nil") { it == nil || (it.present? && it.is_a?(String)) }

    def validate!
      validators.each do |attribute, validator_config|
        validator = validator_config[:validator]
        expecting = validator_config[:expecting]
        value = send(attribute)

        if validator.call(value)
          next
        end

        Rails.logger.error "Skadi.configuration.#{attribute} error! Expecting a #{expecting}, but got a #{value.class}"
      end
    end
  end
end

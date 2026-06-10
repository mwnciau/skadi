module Skadi
  class Configuration
    class Error < StandardError; end

    def initialize
      validators.each do |attribute, validator_config|
        send("#{attribute}=", validator_config[:default])
      end
    end

    cattr_accessor :validators
    self.validators = {}

    def self.validates(attribute, expecting, default:, &block)
      validators[attribute] = {expecting: expecting, default: default, validator: block}
    end

    # An anonymisation set is a token keeps track of a user using a hash of their IP address and User Agent. A
    # cryptographic pepper is added to the hash, which, when discarded, makes the generated token no longer able to
    # be used to track the user. If disabled, views and events will not be linked to a visitor unless a tracking cookie
    # is set. Defaults to true.
    # @return [Boolean]
    attr_accessor :use_anonymisation_sets
    validates(:use_anonymisation_sets, "boolean", default: true) { |it| it == true || it == false }

    # How long an anonymisation set should last before expiring. Defaults to 1 day.
    # @return [ActiveSupport::Duration]
    attr_accessor :anonymisation_set_duration
    validates(:anonymisation_set_duration, "ActiveSupport::Duration", default: 1.day) { |it| it.is_a?(ActiveSupport::Duration) }

    # Set the hour of the day to reset the anonymisation set. Set to false to strictly use the set duration. Defaults to 3 (3am).
    # @return [Integer, false]
    attr_accessor :anonymisation_set_reset_hour
    validates(:anonymisation_set_reset_hour, "Integer or false", default: 3) do |it|
      next true if it == false

      it.is_a?(Integer) && it >= 0 && it <= 23
    end

    # How long a visit should last before expiring. Note: visits that cross anonymisation set boundaries will be counted as two visits. Defaults to 2 hours.
    # @return [ActiveSupport::Duration]
    attr_accessor :visit_duration
    validates(:visit_duration, "ActiveSupport::Duration", default: 2.hours) { |it| it.is_a?(ActiveSupport::Duration) }

    # The parent app's User class, used to link visits to users
    # @return [Class, nil]
    attr_accessor :user_model
    validates(:user_model, "string or nil", default: nil) do |it, config|
      next true if it.nil?

      klass = it.constantize

      next false unless klass.is_a?(Class) && klass < ActiveRecord::Base

      # Update the user_model ref to the actual class rather than the string
      config.user_model = klass

      true
    end

    # Method to call within controllers to get the current user.
    # @return [Symbol, nil]
    attr_accessor :user_method
    validates(:user_method, "Symbol or nil", default: nil) { |it| it.nil? || it.is_a?(Symbol) }

    # Enable filtering of query parameters to prevent sensitive data being exposed. Defaults to true.
    # @return [Boolean]
    attr_accessor :use_query_param_whitelist
    validates(:use_query_param_whitelist, "boolean", default: true) { |it| it == true || it == false }

    # An array of query parameter keys to whitelist for storage in URLs.
    # @return [Array<Symbol>]
    attr_accessor :query_param_whitelist
    validates(:query_param_whitelist, "Array<Symbol>", default: []) { |it| it.is_a?(Array) && it.all? { |key| key.is_a?(Symbol) } }

    # The database connection to use for Skadi models
    # @see ActiveRecord::ConnectionHandling.connects_to
    # @return [Hash, nil]
    attr_accessor :db_connects_to
    validates(:db_connects_to, "Hash compatible with ActiveRecord::ConnectionHandling#connects_to", default: nil) do |it|
      next true if it.nil?

      it.is_a?(Hash) && !it.empty? && it.keys.all? { |key| [:database, :shards].include?(key) }
    end

    # Whether to store the domain when tracking views. Can be useful when using multiple domains or subdomains. Defaults to false.
    # @return [Boolean]
    attr_accessor :store_domain_in_views
    validates(:store_domain_in_views, "boolean", default: false) { |it| it == true || it == false }

    # Sets a limit on the size of the tracking beacon. Defaults to 1KB.
    # @return [Integer]
    attr_accessor :max_tracking_payload_size
    validates(:max_tracking_payload_size, "integer", default: 1_024) { |it| it.is_a?(Integer) && it > 0 }

    # The domain to use when setting cookies. Set to include subdomains. Defaults to nil, which will not specify a domain when setting a cookie.
    # @return [String, nil]
    attr_accessor :cookie_domain
    validates(:cookie_domain, "string or nil", default: nil) { |it| it.nil? || (it.present? && it.is_a?(String)) }

    def validate!
      validators.each do |attribute, validator_config|
        validator = validator_config[:validator]
        expecting = validator_config[:expecting]
        value = send(attribute)

        if validator.call(value, self)
          next
        end

        error = "Skadi.configuration.#{attribute} error! Expecting a #{expecting}, but got a #{value.class}"
        if Rails.env.development?
          raise Error.new(error)
        else
          Rails.logger.error error
        end
      end
    end
  end
end

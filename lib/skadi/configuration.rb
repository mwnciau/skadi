module Skadi
  class Configuration
    class Error < StandardError; end

    def initialize
      validators.each do |attribute, validator_configuration|
        send("#{attribute}=", validator_configuration[:default])
      end
    end

    cattr_accessor :validators
    self.validators = {}

    def self.validates(attribute, expecting, default:, &block)
      validators[attribute] = { expecting: expecting, default: default, validator: block }
    end

    # When enabled, users will automatically be tracked by their anonymity set.
    # An anonymity set keeps track of a user using a hash of their IP address and User Agent. A cryptographic pepper is added to the hash, which, when discarded, makes the generated token no longer able to be used to track the user.
    # When disabled, views and events will not be linked to a visitor without explicit consent to use anonymity sets or tracking cookies.
    # This option defined the default behaviour for using anonymity sets, but the consent cookie, if it exists, will always take precedence over this configuration option.
    # Defaults to false.
    # @return [Boolean]
    attr_accessor :use_anonymity_sets
    validates(:use_anonymity_sets, "boolean", default: false) { |it| it == true || it == false }

    # When enabled, visits will be tracked by using the logged in user. See the :user_model and :user_controller_method configuration options.
    # When disabled, users will not be saved to visits without explicit consent.
    # This option defined the default behaviour for tracking users, but the consent cookie, if it exists, will always take precedence over this configuration option.
    # Defaults to false.
    # @return [Boolean]
    attr_accessor :track_users
    validates(:track_users, "boolean", default: false) { |it| it == true || it == false }

    attr_accessor :anonymity_set_cache_key
    validates(:anonymity_set_cache_key, "string", default: "skadi/anonymity_set_pepper") { |it| it.is_a?(String) && it.present? }

    # How long an anonymity set should last before expiring. Defaults to 1 day.
    # @return [ActiveSupport::Duration]
    attr_accessor :anonymity_set_duration
    validates(:anonymity_set_duration, "ActiveSupport::Duration", default: 1.day) { |it| it.is_a?(ActiveSupport::Duration) }

    # Set the hour of the day to reset the anonymity set. Set to false to strictly use the set duration. Defaults to 3 (3am).
    # @return [Integer, false]
    attr_accessor :anonymity_set_reset_hour
    validates(:anonymity_set_reset_hour, "Integer or false", default: 3) do |it|
      next true if it == false

      it.is_a?(Integer) && it >= 0 && it <= 23
    end

    # How long a visit should last before expiring. Note: visits that cross anonymity set boundaries will be counted as two visits. Defaults to 2 hours.
    # @return [ActiveSupport::Duration]
    attr_accessor :visit_duration
    validates(:visit_duration, "ActiveSupport::Duration", default: 2.hours) { |it| it.is_a?(ActiveSupport::Duration) }

    # The parent app's User class, used to link visits to users
    # @return [Class, nil]
    attr_accessor :user_model
    validates(:user_model, "string or nil", default: nil) do |it, configuration|
      next true if it.nil?
      next false unless it.is_a?(String)

      klass = it.constantize

      next false unless klass.is_a?(Class) && klass < ActiveRecord::Base

      # Update the user_model ref to the actual class rather than the string
      configuration.user_model = klass

      true
    end

    # Method in the host application's ApplicationController that returns the current logged-in user. An AR Model or nil should be returned. Used to track users; if this is nil or set to a non-existent method, user tracking is disabled. Defaults to nil (disabled).
    # @return [Symbol, nil]
    attr_accessor :user_controller_method
    validates(:user_controller_method, "Symbol or nil", default: nil) { |it| it.nil? || it.is_a?(Symbol) }

    # Enable filtering of query parameters to prevent sensitive data being exposed. Defaults to true.
    # @return [Boolean]
    attr_accessor :use_query_param_whitelist
    validates(:use_query_param_whitelist, "boolean", default: true) { |it| it == true || it == false }

    # An array of query parameter keys to whitelist for storage in URLs.
    # @return [Array<Symbol>]
    attr_accessor :query_param_whitelist
    validates(:query_param_whitelist, "Array<Symbol>", default: []) { |it| it.is_a?(Array) && it.all?(Symbol) }

    # Maximum length of the referrer and exit page URLs. Defaults to 2048.
    # @return [Integer]
    attr_accessor :max_url_length
    validates(:max_url_length, "Integer", default: 2048) { |it| it.is_a?(Integer) && it >= 0 }

    # The database connection to use for Skadi models
    # @see ActiveRecord::ConnectionHandling.connects_to
    # @return [Hash, nil]
    attr_accessor :db_connects_to
    validates(:db_connects_to, "Hash compatible with ActiveRecord::ConnectionHandling#connects_to", default: nil) do |it|
      next true if it.nil?

      allowed_keys = [ :database, :shards ].freeze
      it.is_a?(Hash) && !it.empty? && it.keys.all? { |key| allowed_keys.include?(key) }
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

    # Whether to track visits by suspected bots, detected via the browser user agent. Defaults to `Rails.env.local?` (true
    # for development and testing environments, and false for production/other environments).
    attr_accessor :track_bots
    validates(:track_bots, "boolean", default: Rails.env.local?) { |it| it == true || it == false }

    # Helper method to return the inverse of :track_bots
    def do_not_track_bots? = !@track_bots

    ###########################
    # Dashboard configuration #
    ###########################

    # Method in the host application's ApplicationController that returns true if the current request is allowed to view the Skadi dashboard. Defaults to nil (disabled).
    # @return [Symbol, nil]
    attr_accessor :dashboard_view_controller_method
    validates(:dashboard_view_controller_method, "Symbol or nil", default: nil) { |it| it.nil? || it.is_a?(Symbol) }

    # Method in the host application's ApplicationController that returns true if the current request is allowed to edit Skadi dashboards. Defaults to nil (disabled).
    # @return [Symbol, nil]
    attr_accessor :dashboard_edit_controller_method
    validates(:dashboard_edit_controller_method, "Symbol or nil", default: nil) { |it| it.nil? || it.is_a?(Symbol) }

    # Method in the host application's ApplicationController that returns true if the current request is allowed to edit raw SQL in the Skadi dashboard. Note that exposing SQL to users is dangerous and could lead to data loss. Defaults to nil (disabled).
    # @return [Symbol, nil]
    attr_accessor :dashboard_dangerously_use_sql_controller_method
    validates(:dashboard_dangerously_use_sql_controller_method, "Symbol or nil", default: nil) { |it| it.nil? || it.is_a?(Symbol) }

    # Use this to add custom fields to the events dataset in the dashboard. This should be set to a hash with values of the format:
    #   {
    #     label: The label to show in the front end,
    #     type: The datatype, one of :date, :string, :number, :boolean. Defaults to :string if omitted.
    #     filter: `true` if this field can be filtered
    #     split: `true` if this field can be split
    #     sql: The SQL expression used to get this value for derived fields
    #     options: An array of possible values
    #     description: used in the front end as help text for this field
    #   }
    # For example,
    #   {clicks: {type: :number, filter: true, split: true, sql: "properties->>'clicks'"}}
    # See Skadi::Schema for reference
    # @return [Array<Hash>, nil]
    attr_accessor :dashboard_custom_event_fields
    validates(:dashboard_custom_event_fields, "Hash or nil", default: nil) do |it|
      next true if it.nil?
      next false unless it.is_a?(Hash)

      next it.all? do |_key, item|
        item.is_a?(Hash) && (item.keys.map(&:to_s) - %w[label type filter split sql option description]).empty?
      end
    end

    # Use this to add custom database tables to the Skadi dashboard. See Skadi::Schema for reference.
    attr_accessor :dashboard_custom_schema
    validates(:dashboard_custom_schema, "a valid schema or nil", default: nil) do |it|
      next true if it.nil?
      unless it.is_a?(Hash)
        error! "Skadi.configuration.dashboard_custom_schema must be a hash"
        next false
      end

      tables_valid = it.all? do |_table_name, table_schema|
        unless table_schema.is_a?(Hash)
          error! "Skadi.configuration.dashboard_custom_schema values must be a hash"
          next false
        end

        unless table_schema[:model].is_a?(String)
          error! "Skadi.configuration.dashboard_custom_schema hash values must have a :model key"
          next false
        end

        klass = table_schema[:model].constantize
        unless klass.is_a?(Class) && klass < ActiveRecord::Base
          error! "Skadi.configuration.dashboard_custom_schema hash values model key must be the name of a valid model"
          next false
        end

        table_schema[:model] = klass

        unless table_schema[:fields].is_a?(Hash)
          error! "Skadi.configuration.dashboard_custom_schema fields must be a hash"
        end

        next true
      end

      next tables_valid
    end


    def validate!
      validators.each do |attribute, validator_configuration|
        validator = validator_configuration[:validator]
        expecting = validator_configuration[:expecting]
        value = send(attribute)

        if validator.call(value, self)
          next
        end

        error! "Skadi.configuration.#{attribute} error! Expecting a #{expecting}, but got a #{value.class}"
      end
    end

    private def error!(error)
      if Rails.env.local?
        raise Error.new(error)
      else
        Rails.logger.error error
      end
    end
  end
end

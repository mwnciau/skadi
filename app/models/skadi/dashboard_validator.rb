module Skadi
  # Validates that a Dashboard's configuration matches the DashboardConfig type in app/frontend/types.d.ts
  class DashboardValidator < ActiveModel::Validator
    DATASET_TYPES = %w[visits views events percentage sql]

    COMMON_DATASET_TYPE = {
      id: :string,
      label: :string,
      visible: :boolean?,
      axis: ["left", "right", nil],
    }

    # These types closely match the frontend types app/frontend/types.d.ts
    TYPES = {
      DashboardTabConfig: {
        id: :string,
        title: :string,
        description: :string?,
        date_from: :date?,
        date_to: :date?,
        children: :ChartConfigArray
      },
      ChartConfig: {
        id: :string,
        type: %w[bar line],
        title: :string,
        time_series: ["daily", "weekly", "monthly", nil].freeze,
        date_from: :date?,
        date_to: :date?,
        verified: :boolean?,
        unique_visits: :boolean?,
        visit_tracking: ["any", "anonymity_set", "cookie", nil].freeze,
        datasets: :DatasetArray,
      },
      VisitsDataset: {
        **COMMON_DATASET_TYPE,
        type: ["visits"].freeze,
        date_from: :date?,
        date_to: :date?,

        split_by: ["referrer", "landing_page", "utm_source", "utm_medium", "utm_term", "utm_content", "utm_campaign", nil].freeze,

        visit_landing_page: :string?,
        visit_referrer_domain: :string?,

        visit_utm_source: :string?,
        visit_utm_medium: :string?,
        visit_utm_term: :string?,
        visit_utm_content: :string?,
        visit_utm_campaign: :string?,
      },
      ViewsDataset: {
        **COMMON_DATASET_TYPE,
        type: ["views"].freeze,
        date_from: :date?,
        date_to: :date?,

        split_by: ["controller", "controller_action", "path", "verb", "version", nil].freeze,

        view_action: :string?,
        view_controller: :string?,
        view_path: :string?,
        view_verb: :string?,
        view_version: :string?,
      },
      EventsDataset: {
        **COMMON_DATASET_TYPE,
        type: ["events"].freeze,
        date_from: :date?,
        date_to: :date?,

        split_by: ["name", nil].freeze,

        event_name: :string?,
      },
      PercentageDataset: {
        **COMMON_DATASET_TYPE,
        type: ["percentage"].freeze,

        numerator: :dataset_id,
        denominator: :dataset_id,
      },
      SqlDataset: {
        **COMMON_DATASET_TYPE,
        type: ["sql"].freeze,

        sql: :sql,
      },
    }

    Context = Struct.new(:record, :allowed_sql_strings, :dataset_ids)

    def validate(record)
      context = Context.new(record, nil, [])

      validate_type(:DashboardTabConfigArray, record.configuration, "configuration", context:)
    end

    private def validate_type(type, value, path, context:)
      if type.is_a? Hash
        return add_error(path, "must be a hash", context:) unless value.is_a? Hash

        return validate_hash_type(type, value, path, context:)
      end

      if type.is_a? Array
        add_error(path, "must be one of #{type.map(&:inspect).join(", ")}", context:) unless type.include?(value)

        return
      end

      if type.to_s.end_with?("?")
        return if value.nil?

        type = type.to_s.delete_suffix("?").to_sym
      end

      if type.to_s.end_with?("Array")
        return add_error(path, "must be an array", context:) unless value.is_a?(Array)

        type = type.to_s.delete_suffix("Array").to_sym

        return value.each_with_index do |item, index|
          validate_type(type, item, "#{path}[#{index}]", context:)
        end
      end

      case type
      when :string
        add_error(path, "must be a string", context:) unless value.is_a? String
        return
      when :boolean
        add_error(path, "must be a boolean", context:) unless value == true || value == false
        return
      when :date
        add_error(path, "must be a date", context:) unless value.is_a?(String) && value.match?(/\A\d{4}-[01]\d-[0-3]\d\z/)
        return
      when :dataset_id
        add_error(path, "must be a dataset id", context:) unless context.dataset_ids.include?(value)
        return
      when :sql
        return validate_sql(value, path, context:)
      when :Dataset
        return validate_dataset(value, path, context:)
      else
        return validate_custom_type(type, value, path, context:)
      end
    end

    private def validate_sql(value, path, context:)
      return validate_type(:string, value, path, context:) if context.record.can_dangerously_use_sql

      add_error(path, "cannot be modified", context:) unless allowed_sql_strings(context:).include?(value)
    end

    private def validate_dataset(value, path, context:)
      return add_error(path, "must be a hash", context:) unless value.is_a? Hash

      type = value["type"]
      return add_error("#{path}.type", "must be one of #{DATASET_TYPES.map(&:inspect).join(", ")}", context:) unless DATASET_TYPES.include?(type)

      validate_type(:"#{type.upcase_first}Dataset", value, path, context:)
    end

    private def validate_custom_type(type, value, path, context:)
      return add_error(path, "Unknown type #{type.inspect}", context:) unless TYPES.key?(type)

      # Store dataset ids for the current chart for the :dataset_id type
      if type == :ChartConfig && value.is_a?(Hash)
        context.dataset_ids = []
        if value["datasets"].is_a?(Array)
          value["datasets"].each do |dataset|
            context.dataset_ids << dataset["id"] if dataset.is_a?(Hash) && dataset["id"].is_a?(String)
          end
        end
      end

      return validate_type(TYPES[type], value, path, context:)
    end

    private def validate_hash_type(type, value, path, context:)
      extra_keys = value.keys.map(&:to_sym) - type.keys
      extra_keys.each do |key|
        add_error("#{path}.#{key}", "is not a valid key", context:)
      end

      type.each do |item_key, item_type|
        validate_type(item_type, value[item_key.to_s], "#{path}.#{item_key}", context:)
      end
    end

    private def add_error(path, message, context:)
      context.record.errors.add(:configuration, "#{path} #{message}")
    end

    private def allowed_sql_strings(context:)
      # Return the cached SQL strings if already calculated
      return context.allowed_sql_strings if context.allowed_sql_strings.is_a? Array

      return context.allowed_sql_strings = context.record.sql_strings
    end
  end
end

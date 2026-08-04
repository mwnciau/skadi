module Skadi
  # Validates that a Dashboard's configuration matches the DashboardConfig type in app/frontend/types.d.ts
  class DashboardValidator < ActiveModel::Validator
    COMMON_DATASET_FIELDS = {
      id: :string,
      label: :string,
      visible: :boolean?,
      axis: ["left", "right", nil].freeze,
    }

    def self.types
      return @types if defined?(@types)

      @types = {
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
          verified_visits: :boolean?,
          unique_by: ["visit", "visitor", nil],
          visit_tracking: ["any", "anonymity_set", "cookie", nil].freeze,
          datasets: :DatasetArray,
        },
        percentageDataset: {
          **COMMON_DATASET_FIELDS,
          type: ["percentage"].freeze,

          numerator: :dataset_id,
          denominator: :dataset_id,
        },
        sqlDataset: {
          **COMMON_DATASET_FIELDS,
          type: ["sql"].freeze,

          sql: :sql,
        },
      }

      Schema.database_schema.each do |dataset_name, schema|
        dataset_type = COMMON_DATASET_FIELDS.dup
        dataset_type[:type] = [dataset_name.to_s].freeze

        split_by_fields = [nil]

        schema[:fields].each do |field, field_config|
          split_by_fields << field.to_s if field_config[:split]
          next unless field_config[:filter]

          if field_config[:type] == :date
            dataset_type[:"#{field}_from"] = :date?
            dataset_type[:"#{field}_to"] = :date?
          elsif field_config[:options].is_a?(Array)
            dataset_type[field] = [nil, *field_config[:options]]
          else
            dataset_type[field] = :"#{field_config[:type] || :string}?"
          end
        end

        dataset_type[:split_by] = split_by_fields if split_by_fields.length > 1

        @types[:"#{dataset_name}Dataset"] = dataset_type
      end

      return @types
    end

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
      unless context.record.can_dangerously_use_sql
        return add_error(path, "cannot be modified", context:) unless allowed_sql_strings(context:).include?(value)
      end

      unless value.is_a? String
        return add_error(path, "must be a string", context:)
      end

      unless ["date", "split", "count"].all? { |it| value.include?(it) }
        add_error(path, "must include the fields date, split and count", context:)
      end
    end

    private def validate_dataset(value, path, context:)
      return add_error(path, "must be a hash", context:) unless value.is_a? Hash

      type = :"#{value["type"]}Dataset"
      return add_error("#{path}.type", "is not a valid dataset type", context:) unless self.class.types.include?(type)

      validate_type(type, value, path, context:)
    end

    private def validate_custom_type(type, value, path, context:)
      return add_error(path, "Unknown type #{type.inspect}", context:) unless self.class.types.key?(type)

      # Store dataset ids for the current chart for the :dataset_id type
      if type == :ChartConfig && value.is_a?(Hash)
        context.dataset_ids = []
        if value["datasets"].is_a?(Array)
          value["datasets"].each do |dataset|
            context.dataset_ids << dataset["id"] if dataset.is_a?(Hash) && dataset["id"].is_a?(String)
          end
        end
      end

      return validate_type(self.class.types[type], value, path, context:)
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

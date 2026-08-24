module Skadi
  # Validates that a Dashboard's configuration matches the DashboardConfig type in app/frontend/types.d.ts
  class DashboardValidator < ActiveModel::Validator
    OneOf = Struct.new(:allowed_values, :allow_missing)
    ArrayOf = Struct.new(:element_type, :minimum_elements)
    Filter = Struct.new(:filters)

    FILTER_TYPES = {
      boolean: {
        operators: [ "=", "!=", "empty", "not empty" ],
      },
      date: {
        operators: [ "=", ">", ">=", "<=", "<", "!=", "empty", "not empty" ],
      },
      number: {
        operators: [ "=", ">", ">=", "<=", "<", "!=", "empty", "not empty" ],
      },
      one_of: {
        operators: [ "=", "!=", "empty", "not empty" ],
      },
      string: {
        operators: [ "=", "!=", "like", "not like", "empty", "not empty" ],
      },
    }

    COMMON_DATASET_FIELDS = {
      id: :string,
      label: :string,
      visible: :boolean?,
      axis: OneOf.new(allowed_values: %w[left right].freeze, allow_missing: true),
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
          children: ArrayOf.new(:ChartConfig),
        },
        ChartConfig: {
          id: :string,
          type: OneOf.new(allowed_values: %w[bar line table].freeze).freeze,
          title: :string,
          description: :string?,
          time_series: OneOf.new(allowed_values: %w[daily weekly monthly].freeze, allow_missing: true).freeze,
          date_from: :date?,
          date_to: :date?,
          datasets: ArrayOf.new(:Dataset, 1),
        },
        percentageDataset: {
          **COMMON_DATASET_FIELDS,
          type: "percentage",

          numerator: :dataset_id,
          denominator: :dataset_id,
        },
        sqlDataset: {
          **COMMON_DATASET_FIELDS,
          type: "sql",

          sql: :sql,
        },
      }

      Schema.database_schema.each do |dataset_name, schema|
        dataset_type = COMMON_DATASET_FIELDS.dup
        dataset_type[:type] = dataset_name.to_s

        split_by_fields = []
        filters = {}

        schema[:fields].each do |field, field_config|
          split_by_fields << field.to_s if field_config[:split]
          next unless field_config[:filter]

          if field_config[:type] == :one_of
            filters[field] = OneOf.new(allowed_values: field_config[:options], allow_missing: true)
          else
            filters[field] = field_config[:type] || :string
          end
        end

        dataset_type[:count_by] = OneOf.new(allowed_values: [
          dataset_name.to_s,
          # This may result in duplication if the default is overridden, but it will still function correctly
          *schema[:counts]&.keys&.map(&:to_s),
          *schema[:belongs_to]&.keys&.flat_map do |belongs_to_table|
            [
              belongs_to_table.to_s,
              *Schema.database_schema[belongs_to_table][:counts]&.keys&.map(&:to_s),
            ]
          end,
          nil,
        ], allow_missing: true)

        dataset_type[:split_by] = ArrayOf.new(OneOf.new(split_by_fields, false)) if split_by_fields.any?
        dataset_type[:filters] = ArrayOf.new(Filter.new(filters)) if filters.any?

        @types[:"#{dataset_name}Dataset"] = dataset_type
      end

      # Second pass to add the validations for belongs_to fields
      Schema.database_schema.each do |dataset_name, schema|
        next unless schema[:belongs_to].is_a?(Hash) && schema[:belongs_to].any?

        dataset_type = @types[:"#{dataset_name}Dataset"]

        dataset_type[:belongs_to?] = {}
        schema[:belongs_to].keys.each do |association|
          target_table = @types[:"#{association}Dataset"]

          # Double check that this association is actually in the schema
          next unless target_table.is_a?(Hash)

          association_type = { required: :boolean? }
          association_type[:split_by] = target_table[:split_by] if target_table[:split_by]
          association_type[:filters] = target_table[:filters] if target_table[:filters]

          dataset_type[:belongs_to?][:"#{association}?"] = association_type
        end
      end

      return @types
    end

    Context = Struct.new(:record, :allowed_sql_strings, :dataset_ids)

    def validate(record)
      context = Context.new(record, nil, [])

      validate_type(ArrayOf.new(:DashboardTabConfig, 1), record.configuration, "configuration", context:)
    end

    private def validate_type(type, value, path, context:)
      return validate_array_of(type, value, path, context:) if type.is_a?(ArrayOf)
      return validate_hash(type, value, path, context:) if type.is_a?(Hash)
      return validate_filter(type, value, path, context:) if type.is_a?(Filter)
      return validate_one_of(type, value, path, context:) if type.is_a?(OneOf)

      if type.is_a?(String)
        add_error(path, "must be #{type}", context:) unless type == value

        return
      end

      if type.is_a?(Symbol) && type.end_with?("?")
        return if value.nil?

        type = type.to_s.delete_suffix("?").to_sym
      end

      case type
        when :string
          add_error(path, "must be a string", context:) unless value.is_a?(String)
          return
        when :boolean
          add_error(path, "must be a boolean", context:) unless value == true || value == false
          return
        when :number
          add_error(path, "must be a number", context:) unless value.is_a?(Numeric)
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

    # Array of a particular type
    # @param [ArrayOf] type
    private def validate_array_of(type, value, path, context:)
      return if type.minimum_elements.nil? && value.nil?
      return add_error(path, "must be an array", context:) unless value.is_a?(Array)
      return add_error(path, "must have at least one element", context:) if type.minimum_elements == 1 && value.empty?

      return value.each_with_index do |item, index|
        validate_type(type.element_type, item, "#{path}[#{index}]", context:)
      end
    end

    private def validate_hash(type, value, path, context:)
      return add_error(path, "must be a hash", context:) unless value.is_a?(Hash)

      valid_keys = type.keys.map do |key|
        key.to_s.delete_suffix(??)
      end

      extra_keys = value.keys.map(&:to_s) - valid_keys
      extra_keys.each do |key|
        add_error("#{path}.#{key}", "is not a valid key", context:)
      end

      type.each do |item_key, item_type|
        optional = item_key.end_with?(??)
        key = item_key.to_s.delete_suffix(??)

        next if optional && value[key].nil?
        validate_type(item_type, value[key], "#{path}.#{key}", context:)
      end
    end

    private def validate_filter(type, value, path, context:)
      return add_error(path, "must be a Hash", context:) unless value.is_a?(Hash)

      filters = type.filters
      filter_field = value["field"].to_s.to_sym
      return add_error("#{path}.field", "must be one of #{filters.keys.join(", ")}", context:) unless filters.key?(filter_field)

      filter_type = filters[filter_field]
      allowed_operators = FILTER_TYPES[filter_type.is_a?(OneOf) ? :one_of : filter_type][:operators]
      filter_operator = value["operator"]

      return add_error("#{path}.operator", "must be one of #{allowed_operators.join(", ")}", context:) unless allowed_operators.include?(filter_operator)

      # These do not require a value to be specified
      if [ "empty", "not empty" ].include?(filter_operator)
        add_error("#{path}.value", "is not a valid key", context:) if value.key?("value")

        return
      end

      return add_error("#{path}.value", "must be set", context:) if value["value"].nil?

      return validate_type(filter_type, value["value"], "#{path}.value", context:)
    end

    private def validate_one_of(type, value, path, context:)
        return if type.allow_missing && value.nil?
        return if type.allowed_values.include?(value)

        add_error(path, "#{value.inspect} must be one of #{type.allowed_values.map(&:inspect).join(", ")}", context:)
    end

    private def validate_sql(value, path, context:)
      unless context.record.can_dangerously_use_sql
        return add_error(path, "cannot be modified", context:) unless allowed_sql_strings(context:).include?(value)
      end

      unless value.is_a?(String)
        return add_error(path, "must be a string", context:)
      end

      unless [ "date", "split", "count" ].all? { |it| value.include?(it) }
        add_error(path, "must include the fields date, split and count", context:)
      end
    end

    private def validate_dataset(value, path, context:)
      return add_error(path, "must be a hash", context:) unless value.is_a?(Hash)

      type_name = :"#{value["type"]}Dataset"
      return add_error("#{path}.type", "is not a valid dataset type", context:) unless self.class.types.include?(type_name)

      validate_type(self.class.types[type_name], value, path, context:)

      # Perform additional validation of the count_by to ensure the right table is included
      # Early return if the count is the default or is not a string
      return if !value["count_by"].is_a?(String) || value["count_by"] == value["type"]

      count_by = value["count_by"].to_sym

      # Early return if the count is defined or is a foreign key on the current dataset
      schema = Schema.database_schema[value["type"].to_sym]
      return if schema[:counts]&.key?(count_by) || schema[:belongs_to]&.key?(count_by)

      # Find the table that has the given count as one of its counts
      owner = schema[:belongs_to]&.keys&.find do |table|
        Schema.database_schema[table][:counts]&.key?(count_by)
      end

      # Ensure that the relevant table is joined
      if owner && !value["belongs_to"]&.key?(owner.to_s)
        add_error("#{path}.count_by", "#{value["count_by"].inspect} requires a join with the #{owner} table", context:)
      end
    end

    private def validate_custom_type(type, value, path, context:)
      return add_error(path, "Unknown type #{type.inspect}", context:) unless self.class.types.key?(type)

      if type == :ChartConfig && value.is_a?(Hash)
        context.dataset_ids = []

        if value["datasets"].is_a?(Array)
          # Special case for table chart type, limiting datasets to 1 and ruling out derived datasets
          if value["type"] == "table"
            if value["datasets"].is_a?(Array) && value["datasets"].length != 1
              return add_error("#{path}.datasets", "must have one dataset for the table type", context:)
            end
            if value["datasets"].is_a?(Array) && value["datasets"].first.is_a?(Hash) && value["datasets"].first["type"] == "percentage"
              return add_error("#{path}.datasets[0].type", "cannot be percentage for the table type", context:)
            end
          end

          # Store dataset ids for the current chart for the :dataset_id type
          value["datasets"].each do |dataset|
            context.dataset_ids << dataset["id"] if dataset.is_a?(Hash) && dataset["id"].is_a?(String)
          end
        end
      end

      return validate_type(self.class.types[type], value, path, context:)
    end

    private def add_error(path, message, context:)
      context.record.errors.add(:configuration, "#{path} #{message}")
    end

    private def allowed_sql_strings(context:)
      # Return the cached SQL strings if already calculated
      return context.allowed_sql_strings if context.allowed_sql_strings.is_a?(Array)

      return context.allowed_sql_strings = context.record.sql_strings
    end
  end
end

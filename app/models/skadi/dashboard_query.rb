module Skadi
  class DashboardQuery
    class << self
      # Mimics app/frontend/dashboard/dashboardElements/DynamicTable.svelte:13
      ITEMS_PER_PAGE = 10
      PAGES_PER_CHUNK = 10

      def chart_query(chart, untrusted_param_filters)
        queries = chart["datasets"].filter_map do |dataset|
          if dataset["type"] == "sql"
            build_sql_query(dataset, chart, untrusted_param_filters)
          elsif dataset["type"] == "percentage"
            # Percentage charts are handled by the frontend using other datasets
            next
          elsif Schema.database_schema.key?(dataset["type"].to_sym)
            schema = Schema.database_schema[dataset["type"].to_sym]

            build_query_from_schema(dataset, chart, schema, untrusted_param_filters)
          else
            raise ::Skadi::Dashboard::DatasetConfigurationError.new("Unknown dataset type #{dataset["type"]}")
          end
        end

        return { data: [] } unless queries.any?

        result = {
          data: [],
        }
        Skadi::ApplicationRecord.connection.transaction do
          if chart["type"] == "table"
            # Note that the page starts with 1
            page = if untrusted_param_filters["page"].is_a?(Integer) && untrusted_param_filters["page"] > 0
              untrusted_param_filters["page"]
            else
              1
            end

            # We cannot union more than one query when selecting multiple fields for the table dataset so just take the first one as a precaution
            query = queries.first

            result[:resultCount] = Skadi::Visit.connection.select_one("
                SELECT COUNT(*) as count FROM (#{query}) q
            ")["count"]

            last_page = [ 1, (result[:resultCount].to_f / ITEMS_PER_PAGE).ceil ].max
            offset = ([ page, last_page ].min - 1) * ITEMS_PER_PAGE
            limit = ITEMS_PER_PAGE * PAGES_PER_CHUNK

            result[:resultOffset] = offset

            result[:data] = Skadi::Visit.connection.select_all("
                SELECT * FROM (#{query}) q LIMIT #{limit} OFFSET #{offset}
            ")
          else
            result[:data] = Skadi::ApplicationRecord.connection.unprepared_statement do
              Skadi::Visit.connection.select_all(queries.join(" UNION ALL "))
            end
          end

          # Rollback after the SQL is run, preventing some side effects
          raise ActiveRecord::Rollback
        end

        return result
      end

      private def build_sql_query(dataset, chart, untrusted_param_filters)
        model = Skadi::Visit

        safe_group = [ "t.split" ]
        safe_id = model.connection.quote(dataset["id"])

        if chart["time_series"].present?
          safe_aggregated_date = Helpers::Sql.time_series(chart["time_series"], model, "t.date")
          safe_group << safe_aggregated_date
        else
          safe_aggregated_date = "NULL"
        end

        safe_where = build_sql_where(chart, model, untrusted_param_filters)

        return "
            SELECT
              #{safe_id} as id,
              #{safe_aggregated_date} as date,
              t.split as split,
              SUM(t.count) as count
            FROM
              (#{dataset["sql"]}) AS t
            #{safe_where}
            GROUP BY
                #{safe_group.join(", ")}
          "
      end

      private def build_sql_where(chart, model, untrusted_param_filters)
        safe_where = []

        url_date_from = untrusted_param_filters["date_from"] if valid_date_string?(untrusted_param_filters["date_from"])
        date_from = combine_dates(chart["date_from"], url_date_from, type: :from)
        safe_where << "DATE(t.date) >= #{model.connection.quote(date_from)}" unless date_from.nil?

        url_date_to = untrusted_param_filters["date_to"] if valid_date_string?(untrusted_param_filters["date_to"])
        date_to = combine_dates(chart["date_to"], url_date_to, type: :to)
        safe_where << "DATE(t.date) <= #{model.connection.quote(date_to)}" unless date_to.nil?

        return safe_where.any? ? "WHERE #{safe_where.join(" AND ")}" : ""
      end

      private def build_query_from_schema(dataset, chart, schema, untrusted_param_filters)
        query = schema[:model].all

        query = apply_schema_associations(dataset, schema, query)
        query = apply_schema_filters(dataset, schema, query)
        query = apply_chart_filters(dataset, chart, schema, query, untrusted_param_filters)

        query = if chart["type"] == "table"
          select_table_query(dataset, schema, query)
        else
          select_split_and_group_chart_query(dataset, chart, schema, query)
        end

        return query.to_sql
      end

      private def dataset_each_belongs_to(dataset, schema)
        return unless dataset["belongs_to"].is_a?(Hash)

        dataset["belongs_to"].each do |belongs_to_table, belongs_to_config|
          next unless belongs_to_config.is_a?(Hash)

          # Ensure the schema for the current dataset allows joining to the given table
          belongs_to_table = belongs_to_table.to_sym
          next unless schema[:belongs_to]&.key?(belongs_to_table)

          # Ensure the schema for the joined table exists
          belongs_to_schema = Schema.database_schema[belongs_to_table]
          next unless belongs_to_schema

          yield(belongs_to_table, belongs_to_config, belongs_to_schema)
        end
      end

      private def apply_schema_associations(dataset, schema, query)
        dataset_each_belongs_to(dataset, schema) do |belongs_to_table, belongs_to_config, belongs_to_schema|
          join_type = belongs_to_config["required"] ? "INNER JOIN" : "LEFT JOIN"
          model = belongs_to_schema[:model]

          query = query.joins(%(#{join_type} #{model.table_name} ON #{model.table_name}.id = #{schema[:model].table_name}.#{schema[:belongs_to][belongs_to_table][:key]}))
        end

        return query
      end

      POSITIVE_OPERATORS = [ "=", ">", ">=", "<=", "<", "like" ].freeze
      NEGATED_OPERATORS = [ "!=", "not like" ].freeze

      private def apply_schema_filters(dataset, schema, query)
        model = schema[:model]

        if dataset["filters"].is_a?(Array)
          dataset["filters"].each do |filter|
            next unless filter.is_a?(Hash)

            field = filter["field"]
            field_config = schema[:fields][field.to_s.to_sym]
            operator = filter["operator"]
            value = filter["value"]

            next if field_config.nil? || operator.nil? || !field_config[:filter]

            field_type = field_config[:type] || :string
            field_sql = if field_config[:sql]
              field_config[:sql]
            else
              "#{model.table_name}.#{model.connection.quote_column_name(field)}"
            end

            if field_type == :date
              field_sql = "DATE(#{field_sql})"
            end

            if POSITIVE_OPERATORS.include?(operator)
              operator = Helpers::Sql.operator(schema[:model], filter["operator"])

              # For the non-negated operators, we consider an empty string the same as null
              if field_type == :string && value == ""
                query = query.where("#{field_sql} IS NULL OR #{field_sql} #{operator} ?", value)
              else
                query = query.where("#{field_sql} #{operator} ?", value)
              end
            elsif NEGATED_OPERATORS.include?(operator)
              operator = Helpers::Sql.operator(schema[:model], filter["operator"])

              # For the negated operators, we change the behaviour of SQL so that nulls are considered different (rather than defaulting to false)
              if field_type == :string && value == ""
                query = query.where("#{field_sql} #{operator} ?", value)
              else
                query = query.where("#{field_sql} IS NULL OR #{field_sql} #{operator} ?", value)
              end
            elsif operator == "empty"
              if field_type == :string
                query = query.where("#{field_sql} = '' OR #{field_sql} IS NULL")
              else
                query = query.where("#{field_sql} IS NULL")
              end
            elsif operator == "not empty"
              if field_type == :string
                query = query.where("#{field_sql} != '' AND #{field_sql} IS NOT NULL")
              else
                query = query.where("#{field_sql} IS NOT NULL")
              end
            else
              raise Dashboard::UnsupportedOperatorError.new("Unknown operator #{operator}")
            end
          end
        end

        dataset_each_belongs_to(dataset, schema) do |_table, belongs_to_config, belongs_to_schema|
          # Ensure nested belongs_to filters, which aren't supported, don't get applied
          query = apply_schema_filters(belongs_to_config.except("belongs_to"), belongs_to_schema, query)
        end

        return query
      end

      private def apply_chart_filters(_dataset, chart, schema, query, untrusted_param_filters)
        date_config = schema[:fields][:date]

        if date_config
          url_date_from = untrusted_param_filters["date_from"] if valid_date_string?(untrusted_param_filters["date_from"])
          date_from = combine_dates(chart["date_from"], url_date_from, type: :from)
          query = query.where("DATE(#{date_config[:sql]}) >= ?", date_from) unless date_from.nil?

          url_date_to = untrusted_param_filters["date_to"] if valid_date_string?(untrusted_param_filters["date_to"])
          date_to = combine_dates(chart["date_to"], url_date_to, type: :to)
          query = query.where("DATE(#{date_config[:sql]}) <= ?", date_to) unless date_to.nil?
        end

        return query
      end

      private def select_table_query(dataset, schema, query)
        return query.select("'No fields selected' as error") unless dataset["selects"].nil? || dataset["selects"].is_a?(Array)

        selects = dataset["selects"]&.any? ? dataset["selects"] : nil

        # Fall back to selecting all the fields
        selects ||= schema[:fields].keys.map(&:to_s)

        select_fields = selects.map do |field|
          table, field = field.split(".", 2) if field.include?(".")
          next unless table.nil? || (schema[:belongs_to]&.key?(table.to_sym) && dataset["belongs_to"].is_a?(Hash) && dataset["belongs_to"][table].is_a?(Hash))

          field_schema = table.nil? ? schema : Schema.database_schema[table.to_sym]
          next unless field_schema

          field_config = field_schema[:fields][field.to_sym]

          next unless field_config && field_config[:select]

          quoted_field = field_schema[:model].connection.quote_column_name(field)
          quoted_fieldname = if table.nil?
            quoted_field
          else
            field_schema[:model].connection.quote_column_name("#{table}.#{field}")
          end

          if field_config[:sql]
            "#{field_config[:sql]} AS #{quoted_fieldname}"
          else
            "#{field_schema[:model].table_name}.#{quoted_field} AS #{quoted_fieldname}"
          end
        end

        select_fields.compact!
        select_fields = [ "'No fields selected' as error" ] unless select_fields.any?

        return query.select(*select_fields)
      end

      private def select_split_and_group_chart_query(dataset, chart, schema, query)
        model = schema[:model]
        split_columns = safe_split_columns(dataset, schema)

        safe_id = model.connection.quote(dataset["id"])
        safe_date = "NULL"
        safe_split = "NULL"
        safe_count = dataset_count(dataset, schema)
        safe_group = split_columns.dup

        if chart["time_series"].present? && schema[:fields][:date]
          safe_date = Helpers::Sql.time_series(chart["time_series"], model, schema[:fields][:date][:sql])
          safe_group << safe_date
        end

        # If there are split columns, we override the default value of split using them
        if split_columns.length == 1
          safe_split = split_columns.first
        elsif split_columns.length > 1
          # Concatenate the split columns, separating the columns with a token that can be processed in the front end
          safe_split = "CONCAT(#{split_columns.join(", '|~|', ")})"
        end

        return query
            .select(
              "#{safe_id} AS id",
              "#{safe_date} AS date",
              "#{safe_split} AS split",
              "#{safe_count} AS count",
            )
            .group(safe_group)
      end

      private def dataset_count(dataset, schema)
        # Fall back to the name of the current dataset if not set
        count_by = dataset["count_by"].is_a?(String) ? dataset["count_by"].to_sym : dataset["type"].to_sym

        # Match against the current schema's defined counts, allowing for overriding the default
        return schema[:counts][count_by][:sql] if schema[:counts]&.[](count_by)

        # Fallback to basic count if counting by the schema table
        return "COUNT(*)" if count_by == dataset["type"].to_sym

        # If the table is joined, then we can count by using the table's defined counts
        dataset_each_belongs_to(dataset, schema) do |_table, _config, belongs_to_schema|
          return belongs_to_schema[:counts][count_by][:sql] if belongs_to_schema[:counts]&.[](count_by)
        end

        # Fall back to counting by the foreign key
        if schema[:belongs_to].is_a?(Hash)
          schema[:belongs_to].each do |table, config|
            return "COUNT(DISTINCT #{schema[:model].table_name}.#{config[:key]})" if table == count_by
          end
        end

        # For invalid configs, we just fallback to a basic count
        return "COUNT(*)"
      end

      private def safe_split_columns(dataset, schema)
        safe_split = []

        if dataset["split_by"].is_a?(Array)
          dataset["split_by"].each do |field|
            field_config = schema[:fields][field.to_s.to_sym]
            if field_config && field_config[:split]
              safe_field = schema[:model].connection.quote_column_name(field)

              safe_split << (field_config[:sql] || %(#{schema[:model].table_name}.#{safe_field}))
            end
          end
        end

        # Now do the same thing for each belongs_to dataset
        dataset_each_belongs_to(dataset, schema) do |_table, belongs_to_config, belongs_to_schema|
          safe_split.append(*safe_split_columns(belongs_to_config.except("belongs_to"), belongs_to_schema))
        end

        return safe_split
      end

      private def valid_date_string?(date) = date.is_a?(String) && date.match(/\A\d{4}-[01]\d-[0-3]\d\z/)

      # Combine dates for the date ranges, being conservative when combining time ranges
      private def combine_dates(*dates, type:)
        if type == :from
          return dates.compact.max
        end

        return dates.compact.min
      end
    end
  end
end

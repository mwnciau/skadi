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

        return {data: []} unless queries.any?

        result = {
          data: [],
        }
        Skadi::ApplicationRecord.connection.transaction do
          if chart["type"] == "table"
            # Note that the page starts with 1
            page = untrusted_param_filters["page"].is_a?(Integer) ? untrusted_param_filters["page"] : 1

            offset = (page - 1) * ITEMS_PER_PAGE
            limit = ITEMS_PER_PAGE * PAGES_PER_CHUNK

            # We cannot union more than one query when selecting multiple fields for the table dataset so just take the first one as a precaution
            query = queries.first

            result[:resultCount] = Skadi::Visit.connection.select_one("
                SELECT COUNT(*) as count FROM (#{query}) q
            ")["count"]

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

        query = apply_schema_filters(dataset, schema, query)
        query = apply_chart_filters(dataset, chart, schema, query, untrusted_param_filters)

        query = if chart["type"] == "table"
          select_table_query(schema, query)
        else
          select_split_and_group_chart_query(dataset, chart, schema, query)
        end

        return query.to_sql
      end

      private def apply_schema_filters(dataset, schema, query)
        model = schema[:model]

        schema[:fields].each do |field, field_config|
          next unless field_config[:filter]

          # The date field is handled separately (combined with the chart filters)
          next if field == :date

          if field_config[:type] == :date
            if dataset.key?("#{field}_from")
              query = query.where("DATE(#{model.table_name}.#{field}) >= ?", dataset["#{field}_from"])
            end
            if dataset.key?("#{field}_to")
              query = query.where("DATE(#{model.table_name}.#{field}) <= ?", dataset["#{field}_to"])
            end
          elsif dataset.key?(field.to_s)
            field_sql = field_config[:sql] ? field_config[:sql] : "#{model.table_name}.#{model.connection.quote_column_name(field)}"
            untrusted_value = dataset[field.to_s]

            if field_config[:type].nil? || field_config[:type] == :string
              like = Helpers::Sql.ilike(model)
              if untrusted_value&.start_with?("!")
                untrusted_value.delete_prefix!("!")

                query = query.where("#{field_sql} IS NULL OR #{field_sql} NOT #{like} ?", untrusted_value)
              else
                query = query.where("#{field_sql} #{like} ?", untrusted_value)
              end
            else
              query = query.where("#{field_sql} = ?", dataset[field.to_s])
            end
          end
        end

        return query
      end

      private def apply_chart_filters(dataset, chart, schema, query, untrusted_param_filters)
        date_config = schema[:fields][:date]

        if date_config
          url_date_from = untrusted_param_filters["date_from"] if valid_date_string?(untrusted_param_filters["date_from"])
          date_from = combine_dates(chart["date_from"], dataset["date_from"], url_date_from, type: :from)
          query = query.where("DATE(#{date_config[:sql]}) >= ?", date_from) unless date_from.nil?

          url_date_to = untrusted_param_filters["date_to"] if valid_date_string?(untrusted_param_filters["date_to"])
          date_to = combine_dates(chart["date_to"], dataset["date_to"], url_date_to, type: :to)
          query = query.where("DATE(#{date_config[:sql]}) <= ?", date_to) unless date_to.nil?
        end

        if schema[:visit_key]
          # Join the visits if we need to
          if chart["verified_visits"] == true || chart["visit_tracking"] || chart["unique_by"] == "visitor"
            if schema[:model] != Skadi::Visit
              query = query.joins(%(INNER JOIN skadi_visits ON skadi_visits.id = #{schema[:model].table_name}.#{schema[:visit_key]}))
            end
          end

          if chart["verified_visits"] == true
            # Either this visit is linked to a verified visit, or it is not linked at all
            query = query.where("skadi_visits.verified = TRUE")
          end

          if chart["visit_tracking"] == "any"
            query = query.where("skadi_visits.tracking_token IS NOT NULL")
          elsif chart["visit_tracking"] == "anonymity_set"
            query = query.where("skadi_visits.tracking_token IS NOT NULL AND skadi_visits.cookies_enabled = FALSE")
          elsif chart["visit_tracking"] == "cookie"
            query = query.where("skadi_visits.tracking_token IS NOT NULL AND skadi_visits.cookies_enabled = TRUE")
          end
        end

        return query
      end

      private def select_table_query(schema, query)
        model = schema[:model]
        select_fields = schema[:fields].map do |key, field_config|
          quoted_field = model.connection.quote_column_name(key)

          if field_config[:sql]
            "#{field_config[:sql]} AS #{quoted_field}"
          else
            "#{model.table_name}.#{quoted_field}"
          end
        end

        return query.select(*select_fields)
      end

      private def select_split_and_group_chart_query(dataset, chart, schema, query)
        model = schema[:model]
        split_columns = safe_split_columns(dataset, schema)

        safe_id = model.connection.quote(dataset["id"])
        safe_date = "NULL"
        safe_split = "NULL"
        safe_count = "COUNT(*)"
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

        if schema[:count_sql]
          safe_count = schema[:count_sql]
        elsif chart["unique_by"] == "visit" && schema[:visit_key]
          safe_count = "COUNT(DISTINCT #{schema[:model].table_name}.#{schema[:visit_key]})"
        elsif chart["unique_by"] == "visitor" && schema[:visit_key]
          safe_count = "COUNT(DISTINCT skadi_visits.tracking_token)"
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

      private def safe_split_columns(dataset, schema)
        safe_split = []

        if dataset["split_by"].is_a?(Array)
          dataset["split_by"].each do |field|
            field_config = schema[:fields][field.to_sym]
            if field_config && field_config[:split]
              safe_field = schema[:model].connection.quote_column_name(field)

              safe_split << (field_config[:sql] || %(#{schema[:model].table_name}.#{safe_field}))
            end
          end
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

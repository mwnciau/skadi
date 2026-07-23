module Skadi
  class DashboardQuery
    class << self
      GROUPINGS = {
        "daily" => {
          "PostgreSQL" => "DATE(<table_name>.created_at)",
          "Mysql2" => "DATE(<table_name>.created_at)",
          "SQLite" => "DATE(<table_name>.created_at)"
        },
        "weekly" => {
          "PostgreSQL" => "DATE_TRUNC('week', <table_name>.created_at)::date",
          "Mysql2" => "DATE_SUB(DATE(<table_name>.created_at), INTERVAL WEEKDAY(<table_name>.created_at) DAY)",
          "SQLite" => "DATE(<table_name>.created_at, '-' || ((CAST(STRFTIME('%w', <table_name>.created_at) AS INTEGER) + 6) % 7) || ' days')"
        },
        "monthly" => {
          "PostgreSQL" => "DATE_TRUNC('month', <table_name>.created_at)::date",
          "Mysql2" => "DATE_FORMAT(<table_name>.created_at, '%Y-%m-01')",
          "SQLite" => "DATE(<table_name>.created_at, 'start of month')"
        }
      }

      VALID_SPLIT_BY = {
        Skadi::View => %w[controller controller_action path verb version],
        Skadi::Visit => %w[referrer landing_page utm_source utm_medium utm_term utm_content utm_campaign],
        Skadi::Event => %w[name]
      }

      def chart_query(chart, global_filters)
        # Overwrite the chart config with the passed in global filters
        chart["date_from"] = combine_dates(chart["date_from"], global_filters["date_from"], type: :from)
        chart["date_to"] = combine_dates(chart["date_to"], global_filters["date_to"], type: :to)

        queries = chart["datasets"].filter_map do |dataset|
          case dataset["type"]
          when "visits"
            build_query(Skadi::Visit, dataset, chart)
          when "views"
            build_query(Skadi::View, dataset, chart)
          when "events"
            build_query(Skadi::Event, dataset, chart)
          when "sql"
            dataset["sql"]
          when "percentage"
            # Percentage charts are handled by the frontend using other datasets
            next
          else
            raise dataset.inspect
          end
        end

        return Skadi::ApplicationRecord.connection.unprepared_statement do
          queries.map! do |query|
            next query if query.is_a?(String)

            next query.to_sql
          end

          Skadi::Visit.connection.select_all(queries.join(" UNION ALL "))
        end
      end

      private def build_query(model, dataset, chart)
        query = model.all
        query = add_query_select(query, model, dataset, chart)
        query = apply_global_filters(query, dataset, chart)

        query = case model.to_s
          when "Skadi::Visit"
            apply_visit_filters(query, dataset, chart)
          when "Skadi::View"
            apply_view_filters(query, dataset, chart)
          when "Skadi::Event"
            apply_event_filters(query, dataset, chart)
          else query
        end

        return query
      end

      private def add_query_select(query, model, dataset, chart)
        # Variables named safe_* are using our definitions, or are escaped user input

        safe_group = []

        safe_dataset_id = model.connection.quote(dataset["id"])
        safe_split = "NULL"

        valid_split_by = false
        if dataset["split_by"].present?
          if VALID_SPLIT_BY[model]&.include?(dataset["split_by"])
            valid_split_by = true

            split_columns = if dataset["split_by"] == "controller_action"
              ["#{model.table_name}.controller", "#{model.table_name}.action"]
            elsif dataset["split_by"] == "referrer"
              [sql_referrer_domain(model)]
            else
              ["#{model.table_name}.#{dataset["split_by"]}"]
            end

            safe_split = "CONCAT(#{split_columns.join(", '::', ")})"
            safe_group.push(*split_columns)
          end
        end

        safe_label = model.connection.quote(dataset["label"])

        if chart["time_series"].present?
          group_template = (GROUPINGS[chart["time_series"]]).fetch(model.connection.adapter_name) do
            raise "Unsupported database adapter for grouping: #{model.connection.adapter_name}"
          end

          # This is a SQL safe string because it can only contain the values in `GROUPINGS`
          safe_label = group_template.gsub("<table_name>", model.table_name)
          safe_group << [safe_label]
        elsif valid_split_by
          # If there is no time series, then we include the split in the label so that the x values are all different for the charts
          safe_label = "CONCAT(#{safe_label}, ' ', #{safe_split})"
        end

        safe_count = if (model == Skadi::View || model == Skadi::Event) && chart["unique_visits"] == true
          "COUNT(DISTINCT #{model.table_name}.visit_id) AS count"
        else
          "COUNT(*) AS count"
        end

        query.select(
          "#{safe_dataset_id} as id",
          "#{safe_split} as split",
          "#{safe_label} AS label",
          safe_count
        )
          .group(safe_group)
      end

      private def apply_global_filters(query, dataset, chart)
        # General rule throughout this method: if it exists in the query filters, use that. Otherwise, use
        # the dataset filters.

        table = query.arel_table.name

        date_from = combine_dates(chart["date_from"], dataset["date_from"], type: :from)
        date_from = parse_time(date_from)&.to_date if date_from
        query = query.where("DATE(#{table}.created_at) >= ?", date_from) unless date_from.nil?

        date_to = combine_dates(chart["date_to"], dataset["date_to"], type: :to)
        date_to = parse_time(date_to)&.to_date if date_to
        query = query.where("DATE(#{table}.created_at) <= ?", date_to) unless date_to.nil?

        return query
      end

      private def apply_visit_filters(query, dataset, chart)
        query = query.where(verified: true) if chart["verified"] == true

        visit_filter_fields = %w[utm_source utm_medium utm_term utm_content utm_campaign landing_page]
        visit_filter_fields.each do |field|
          key = "visit_#{field}"
          if dataset.key?(key)
            query = query.where(field => dataset[key])
          end
        end

         if dataset.key?("visit_referrer_domain")
           query = query.where("#{sql_referrer_domain(Skadi::Visit)} = ?", dataset["visit_referrer_domain"])
         end

        query = apply_common_visit_filters(query, dataset, chart)

        return query
      end

      private def apply_view_filters(query, dataset, chart)
        query = query.where(verified: true) if chart["verified"] == true

        view_filter_fields = %w[path controller action verb version]
        view_filter_fields.each do |field|
          key = "view_#{field}"
          if dataset.key?(key)
            query = query.where(field => dataset[key])
          end
        end

        if chart["visit_tracking"].present?
          query = query.joins(:visit)

          query = apply_common_visit_filters(query, dataset, chart)
        end

        return query
      end

      private def apply_common_visit_filters(query, dataset, chart)
        if chart["visit_tracking"] == "any"
          query = query.where("skadi_visits.tracking_token IS NOT NULL")
        elsif chart["visit_tracking"] == "anonymity_set"
          query = query.where("skadi_visits.tracking_token IS NOT NULL AND cookies_enabled = FALSE")
        elsif chart["visit_tracking"] == "cookie"
          query = query.where("skadi_visits.tracking_token IS NOT NULL AND cookies_enabled = TRUE")
        end

        return query
      end

      private def apply_event_filters(query, dataset, chart)
        if dataset.key?("event_name")
          query = query.where(name: dataset["event_name"])
        end

        if chart["visit_tracking"] || chart["verified"] == true || chart["unique_visits"] == true
          query = query.left_joins(:visit)

          query = apply_common_visit_filters(query, dataset, chart)

          if chart["verified"] == true
            # Either this visit is linked to a verified visit, or it is not linked at all
            query = query.where("skadi_visits.id IS NULL OR skadi_visits.verified = TRUE")
          end

          if chart["unique_visits"] == true
            # If we are looking for unique visits, then we need to be linked to a visit
            query = query.where("skadi_visits.id IS NOT NULL")
          end
        end

        return query
      end

      private def parse_time(user_supplied_date)
        return Time.zone.parse(user_supplied_date)
      end

      # Combine dates for the date ranges, being conservative when combining time ranges
      private def combine_dates(*dates, type:)
        if type == :from
          return dates.compact.max
        end

        return dates.compact.min
      end

      private def sql_referrer_domain(model)
        case model.connection.adapter_name
        when "PostgreSQL"
          "SPLIT_PART(#{model.table_name}.referrer, '/', 1)"
        when "Mysql2"
          "SUBSTRING_INDEX(#{model.table_name}.referrer, '/', 1)"
        when "SQLite"
          "SUBSTR(#{model.table_name}.referrer, 1, INSTR(#{model.table_name}.referrer, '/') - 1)"
        else
          "#{model.table_name}.referrer"
        end
      end
    end
  end
end

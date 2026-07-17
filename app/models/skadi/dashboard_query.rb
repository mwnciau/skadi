module Skadi
  class DashboardQuery
    class << self
      GROUPINGS = {
        "day" => {
          "PostgreSQL" => "DATE(<table_name>.created_at)",
          "Mysql2" => "DATE(<table_name>.created_at)",
          "SQLite" => "DATE(<table_name>.created_at)"
        },
        "week" => {
          "PostgreSQL" => "DATE_TRUNC('week', <table_name>.created_at)::date",
          "Mysql2" => "DATE_SUB(DATE(<table_name>.created_at), INTERVAL WEEKDAY(<table_name>.created_at) DAY)",
          "SQLite" => "DATE(<table_name>.created_at, '-' || ((CAST(STRFTIME('%w', <table_name>.created_at) AS INTEGER) + 6) % 7) || ' days')"
        },
        "month" => {
          "PostgreSQL" => "DATE_TRUNC('month', <table_name>.created_at)::date",
          "Mysql2" => "DATE_FORMAT(<table_name>.created_at, '%Y-%m-01')",
          "SQLite" => "DATE(<table_name>.created_at, 'start of month')"
        }
      }
      VIEW_SPLIT_BY = ["controller", "controller_action", "path", "verb", "version"]

      def chart_query(chart, global_filters)
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
        safe_label = model.connection.quote(dataset["label"])

        if chart["group"].present?
          group_template = (GROUPINGS[chart["group"]]).fetch(model.connection.adapter_name) do
            raise "Unsupported database adapter for grouping: #{model.connection.adapter_name}"
          end

          # This is a SQL safe string because it can only contain the values in `GROUPINGS`
          safe_label = group_template.gsub("<table_name>", model.table_name)
          safe_group << [safe_label]
        end

        safe_dataset_id = model.connection.quote(dataset["id"])
        safe_split = "NULL"

        valid_split_by = false
        valid_split_by ||= model == Skadi::View && dataset["split_by"].present? && VIEW_SPLIT_BY.include?(dataset["split_by"])
        valid_split_by ||= model == Skadi::Event && dataset["split_by"] == "name"
        if valid_split_by
          split_columns = if dataset["split_by"] == "controller_action"
            ["#{model.table_name}.controller", "#{model.table_name}.action"]
          else
            ["#{model.table_name}.#{dataset["split_by"]}"]
          end

          safe_split = "CONCAT(#{split_columns.join(", '::', ")})"
          safe_group.push(*split_columns)
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

        table = query.arel_table

        date_filters = if chart.key?("date_from") || chart.key?("date_to")
          chart
        elsif dataset.key?("date_from") || dataset.key?("date_to")
          dataset
        end
        from = parse_time(date_filters["date_from"]) if date_filters&.key?("date_from")
        to = parse_time(date_filters["date_to"]) if date_filters&.key?("date_to")
        query = query.where("DATE(#{table}.created_at) >= ?", from.to_date) unless from.nil?
        query = query.where("DATE(#{table}.created_at) <= ?", to.to_date) unless to.nil?

        return query
      end

      private def apply_visit_filters(query, dataset, chart)
        query = query.where(verified: true) if chart["verified"] == true

        query = apply_common_visit_filters(query, dataset, chart)

        return query
      end

      private def apply_view_filters(query, dataset, chart)
        query_filter_fields = ["path", "controller", "action", "verb", "version"]

        query = query.where(verified: true) if chart["verified"] == true

        query_filter_fields.each do |field|
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

      private def apply_common_visit_filters(query, _dataset, chart)
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
    end
  end
end

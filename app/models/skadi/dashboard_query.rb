module Skadi
  class DashboardQuery
    class << self
      GROUPINGS = {
        "day" => "DATE(%s.created_at)"
        # TODO: add week and month
      }
      VIEW_SPLIT_BY = ["controller", "controller_action", "path", "verb"]

      def chart_query(chart, global_filters)
        queries = chart["datasets"].filter_map do |dataset|
          case dataset["type"]
          when "visits"
            build_query(Skadi::Visit, dataset, chart)
          when "views"
            build_query(Skadi::View, dataset, chart)
          when "percentage"
            # Percentage charts are handled by the frontend using other datasets
            next
          else
            raise dataset.inspect
          end
        end

        return Skadi::ApplicationRecord.connection.unprepared_statement do
          Skadi::Visit.connection.select_all(queries.map(&:to_sql).join(" UNION ALL "))
        end
      end

      private def build_query(model, dataset, chart)
        query = model.all
        query = add_query_select(query, model, dataset, chart)
        query = apply_global_filters(query, dataset, chart)

        query = case model.to_s
          when "Skadi::View"
            apply_view_filters(query, dataset)
          when "Skadi::Visit"
            apply_visit_filters(query, dataset)
          else query
        end

        return query
      end

      private def add_query_select(query, model, dataset, chart)
        # This is a SQL safe string because it can only contain the values in `GROUPINGS`
        label = (GROUPINGS[chart["group"]] || GROUPINGS["day"]) % model.table_name
        safe_group = [label]

        safe_dataset_id = model.connection.quote(dataset["id"])

        if model == Skadi::View && dataset["split_by"] && VIEW_SPLIT_BY.include?(dataset["split_by"])
          split_columns = if dataset["split_by"] == "controller_action"
            ["skadi_views.controller", "skadi_views.action"]
          else
            ["skadi_views.#{dataset["split_by"]}"]
          end

          safe_dataset_id = "CONCAT(#{safe_dataset_id}, ' ', #{split_columns.join(", '::', ")})"
          safe_group.push(*split_columns)
        end

        count = if model == Skadi::View && dataset["unique_visits"] == true
          "COUNT(DISTINCT skadi_views.visit_id) AS count"
        else
          "COUNT(*) AS count"
        end

        query.select("#{safe_dataset_id} as id", "#{label} AS label", count)
          .group(safe_group)
      end

      private def apply_global_filters(query, dataset, chart)
        # General rule throughout this method: if it exists in the query filters, use that. Otherwise, use
        # the dataset filters.

        table = query.arel_table

        verified = false
        if dataset.key?("verified")
          verified = true if dataset["verified"] == true
        end
        query = query.where(verified: true) if verified

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

      private def apply_view_filters(query, dataset_filters)
        query_filter_fields = ["path", "controller", "action", "verb"]

        query_filter_fields.each do |field|
          key = "view_#{field}"
          if dataset_filters.key?(key)
            query = query.where(field => dataset_filters[key])
          end
        end

        if dataset_filters["visit_tracking"]
          query = query.joins(:visit)

          query = apply_visit_filters(query, dataset_filters)
        end

        return query
      end

      private def apply_visit_filters(query, dataset_filters)
        if dataset_filters["visit_tracking"] == "any"
          query = query.where("skadi_visits.tracking_token IS NOT NULL")
        elsif dataset_filters["visit_tracking"] == "anonymity_set"
          query = query.where("skadi_visits.tracking_token IS NOT NULL AND cookies_enabled = FALSE")
        elsif dataset_filters["visit_tracking"] == "cookie"
          query = query.where("skadi_visits.tracking_token IS NOT NULL AND cookies_enabled = TRUE")
        end

        return query
      end

      private def parse_time(user_supplied_date)
        return Time.zone.parse(user_supplied_date)
      end
    end
  end
end

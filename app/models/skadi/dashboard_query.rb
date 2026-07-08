module Skadi
  class DashboardQuery
    class << self
      GROUPINGS = {
        "day" => "DATE(%s.created_at)"
      }

      def chart_query(chart, query_filters)
        queries = chart["datasets"].filter_map do |dataset|
          case dataset["type"]
          when "visits"
            build_query(Skadi::Visit, dataset, query_filters)
          when "views"
            build_query(Skadi::View, dataset, query_filters)
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

      private def build_query(model, dataset, query_filters)
        # This is a SQL safe string because it can only contain the values in `GROUPINGS`
        safe_grouping = (GROUPINGS[dataset["group"]] || GROUPINGS["day"]) % model.table_name

        safe_id_node = Arel::Nodes.build_quoted(dataset["id"]).as('id')

        query = model
          .select(safe_id_node, "#{safe_grouping} AS label", "COUNT(*) AS count")
          .group(safe_grouping)

        query = apply_global_filters(query, dataset["filters"], query_filters)

        query = case model.to_s
          when "Skadi::View"
            apply_view_filters(query, dataset["filters"], query_filters)
          else query
        end

        return query
      end

      private def apply_global_filters(query, dataset_filters, query_filters)
        # General rule throughout this method: if it exists in the query filters, use that. Otherwise, use
        # the dataset filters.

        table = query.arel_table

        verified = false
        if query_filters.key?("verified")
          verified = true if query_filters["verified"] == true
        elsif dataset_filters.key?("verified")
          verified = true if dataset_filters["verified"] == true
        end
        query = query.where(verified: true) if verified

        date_filters = if query_filters.key?("date_from") || query_filters.key?("date_to")
          query_filters
        elsif dataset_filters.key?("date_from") || dataset_filters.key?("date_to")
          dataset_filters
        end
        from = parse_time(date_filters["date_from"]) if date_filters&.key?("date_from")
        to = parse_time(date_filters["date_to"]) if date_filters&.key?("date_to")
        query = query.where("DATE(#{table}.created_at) >= ?", from.to_date) unless from.nil?
        query = query.where("DATE(#{table}.created_at) <= ?", to.to_date) unless to.nil?

        return query
      end

      private def apply_view_filters(query, dataset_filters, query_filters)
        query_filter_fields = ["path", "action", "method", "verb"]

        query_filter_fields.each do |field|
          if query_filters.key?(field)
            query = query.where(field => query_filters[field])
          elsif dataset_filters.key?(field)
            query = query.where(field => dataset_filters[field])
          end
        end

        if dataset_filters["visit"] == true
          query = query.where("visit_id IS NOT NULL")
        elsif dataset_filters["visit"].is_a? Hash
          query = query.joins(:visit)

          if dataset_filters["visit"]["verified"] == true
            query = query.where("skadi_visits.verified = true")
          end
          if dataset_filters["visit"]["tracked"] == true
            query = query.where("skadi_visits.tracking_token IS NOT NULL")
          elsif dataset_filters["visit"]["tracked"] == "anonymity_set"
            # Todo: update the database to allow for tracking type detection
          elsif dataset_filters["visit"]["tracked"] == "cookie"
            # Todo: update the database to allow for tracking type detection
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

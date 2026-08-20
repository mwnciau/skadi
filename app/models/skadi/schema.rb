module Skadi
  class Schema
    class << self
      # Extract out the most common field config into a const
      SELECT_FILTER_AND_SPLIT = { select: true, filter: true, split: true }
      private_constant :SELECT_FILTER_AND_SPLIT

      # A hash where the key represents a dataset name and the value is its configuration
      def database_schema
        return @_database_schema if defined?(@_database_schema)

        @_database_schema ||= {
          # A hash with the following keys:
          # model: The model for this dataset
          # visit_key: used for chart-level visit filters
          # count_sql: The SQL expression used to count this field. Defaults to COUNT().
          # belongs_to: A hash describing belongs_to relationships, e.g. {visits: {key: :visit_id}}
          # fields: A hash where the key represents a field and the value is its configuration
          visits: {
            model: Skadi::Visit,
            visit_key: "id",
            # If the table has a date field, the fields Hash expects a value for :date
            fields: {
              # A hash with the following keys:
              # label: The label to show in the front end
              # type: The datatype, one of :one_of, :date, :string, :number, :boolean. Defaults to :string.
              # select: True if this field can be selected by the table chart
              # filter: True if this field can be filtered
              # split: True if this field can be split
              # sql: The SQL expression used to get this value for derived fields
              # options: A list of possible values
              # description: used in the front end as help text for this field
              date: {
                type: :date,
                select: true,
                filter: true,
                sql: "skadi_visits.created_at",
              },
              verified: {
                **SELECT_FILTER_AND_SPLIT,
                type: :boolean,
              },
              tracked: {
                **SELECT_FILTER_AND_SPLIT,
                type: :boolean,
                sql: "(skadi_visits.tracking_token IS NOT NULL)",
                description: "Whether the visit is tracked across multiple views and events using a cookie or anonymity set.",
              },
              cookies_enabled: {
                **SELECT_FILTER_AND_SPLIT,
                type: :boolean,
                description: "Whether this visit is tracked across multiple days using cookies.",
              },
              landing_page: SELECT_FILTER_AND_SPLIT,
              referrer_domain: {
                **SELECT_FILTER_AND_SPLIT,
                sql: Helpers::Sql.string_before_separator(Skadi::Visit, "referrer", "/"),
              },
              utm_source: SELECT_FILTER_AND_SPLIT,
              utm_medium: SELECT_FILTER_AND_SPLIT,
              utm_term: SELECT_FILTER_AND_SPLIT,
              utm_content: SELECT_FILTER_AND_SPLIT,
              utm_campaign: SELECT_FILTER_AND_SPLIT,
            },
          },
          views: {
            model: Skadi::View,
            visit_key: "visit_id",
            belongs_to: { visits: { key: :visit_id } },
            fields: {
              date: {
                type: :date,
                select: true,
                filter: true,
                sql: "skadi_views.created_at",
              },
              verified: {
                **SELECT_FILTER_AND_SPLIT,
                type: :boolean,
              },
              controller: SELECT_FILTER_AND_SPLIT,
              action: {
                select: true,
                filter: true,
              },
              controller_and_action: {
                select: true,
                split: true,
                sql: "CONCAT(skadi_views.controller, '::', skadi_views.action)",
              },
              path: SELECT_FILTER_AND_SPLIT,
              verb: {
                **SELECT_FILTER_AND_SPLIT,
                type: :one_of,
                description: "Typically, GET requests are page views, and POST, PUT, PATCH and DELETE are form submissions.",
                options: %w[GET POST PUT PATCH DELETE],
              },
              version: SELECT_FILTER_AND_SPLIT,
              exit_page: SELECT_FILTER_AND_SPLIT,
            },
          },
          events: {
            model: Skadi::Event,
            visit_key: "visit_id",
            belongs_to: { visits: { key: :visit_id }, views: { key: :view_id } },
            fields: {
              date: {
                type: :date,
                select: true,
                filter: true,
                sql: "skadi_events.created_at",
              },
              name: SELECT_FILTER_AND_SPLIT,
              **(Skadi.configuration.dashboard_custom_event_fields || {}),
            },
          },
          demographics: {
            model: Demographic,
            count_sql: "COALESCE(SUM(skadi_demographics.count), 0)",
            fields: {
              date: {
                type: :date,
                select: true,
                filter: true,
                sql: "skadi_demographics.recorded_on",
              },
              uri: SELECT_FILTER_AND_SPLIT,
              name: SELECT_FILTER_AND_SPLIT,
              value: SELECT_FILTER_AND_SPLIT,
              count: {
                **SELECT_FILTER_AND_SPLIT,
                type: :number,
              },
            },
          },
          **(Skadi.configuration.dashboard_custom_schema || {}),
        }
      end

      def frontend_schema
        return @_frontend_schema if defined?(@_frontend_schema)

        # Redact the SQL from the dashboard schema
        schema = database_schema.deep_dup
        schema.each_value do |dataset|
          dataset.keys.each do |key|
            dataset.delete(key) unless key == :fields
          end

          dataset[:fields].each_value do |field|
            field.delete(:sql)
          end
        end

        @_frontend_schema = schema
      end
    end
  end
end

module Skadi
  class Schema
    class << self
      # Extract out the most common field config into a const
      FILTER_AND_SPLIT = { filter: true, split: true }
      private_constant :FILTER_AND_SPLIT

      DATE_DESCRIPTION = "These dates are combined with the dashboard and chart's dates to further limit the date range returned by the dataset."
      private_constant :DATE_DESCRIPTION

      # A hash where the key represents a dataset name and the value is its configuration
      def database_schema
        return @_database_schema if defined?(@_database_schema)

        @_database_schema ||= {
          # A hash with the following keys:
          # model: The model for this dataset
          # visit_key: used for chart-level visit filters
          # count_sql: The SQL expression used to count this field. Defaults to COUNT().
          # fields: A hash where the key represents a field and the value is its configuration
          visits: {
            model: Skadi::Visit,
            visit_key: "id",
            # If the table has a date field, the fields Hash expects a value for :date
            fields: {
              # A hash with the following keys:
              # label: The label to show in the front end
              # type: The datatype, one of :date, :string, :number, :boolean. Defaults to :string.
              # filter: True if this field can be filtered
              # split: True if this field can be split
              # sql: The SQL expression used to get this value for derived fields
              # options: A list of possible values
              # description: used in the front end as help text for this field
              date: {
                type: :date,
                filter: true,
                sql: "skadi_visits.created_at",
                description: DATE_DESCRIPTION,
              },
              landing_page: FILTER_AND_SPLIT,
              referrer_domain: {
                **FILTER_AND_SPLIT,
                sql: Helpers::Sql.string_before_separator(Skadi::Visit, "referrer", "/"),
              },
              utm_source: FILTER_AND_SPLIT,
              utm_medium: FILTER_AND_SPLIT,
              utm_term: FILTER_AND_SPLIT,
              utm_content: FILTER_AND_SPLIT,
              utm_campaign: FILTER_AND_SPLIT,
            },
          },
          views: {
            model: Skadi::View,
            visit_key: "visit_id",
            fields: {
              date: {
                type: :date,
                filter: true,
                sql: "skadi_views.created_at",
                description: DATE_DESCRIPTION,
              },
              verified: {
                type: :boolean,
                filter: true,
              },
              controller: FILTER_AND_SPLIT,
              action: FILTER_AND_SPLIT,
              controller_and_action: {
                split: true,
                sql: "CONCAT(skadi_views.controller, '::', skadi_views.action)",
              },
              path: FILTER_AND_SPLIT,
              verb: {
                filter: true,
                split: true,
                description: "Typically, GET requests are page views, and POST, PUT, PATCH and DELETE are form submissions.",
                options: %w[GET POST PUT PATCH DELETE],
              },
              version: FILTER_AND_SPLIT,
              exit_page: FILTER_AND_SPLIT,
            },
          },
          events: {
            model: Skadi::Event,
            visit_key: "visit_id",
            fields: {
              date: {
                type: :date,
                filter: true,
                sql: "skadi_events.created_at",
                description: DATE_DESCRIPTION,
              },
              name: FILTER_AND_SPLIT,
            },
          },
          demographics: {
            model: Demographic,
            count_sql: "COALESCE(SUM(skadi_demographics.count), 0)",
            fields: {
              date: {
                type: :date,
                filter: true,
                sql: "skadi_demographics.recorded_on",
                description: DATE_DESCRIPTION,
              },
              uri: FILTER_AND_SPLIT,
              name: FILTER_AND_SPLIT,
              value: FILTER_AND_SPLIT,
            },
          },
        }
      end

      def frontend_schema
        return @_frontend_schema if defined?(@_frontend_schema)

        # Redact the SQL from the dashboard schema
        schema = database_schema.deep_dup
        schema.each_value do |dataset|
          Object.keys(dataset).each do |key|
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

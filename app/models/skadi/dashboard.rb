module Skadi
  class Dashboard < ApplicationRecord
    validates_with DashboardValidator

    # Used by the validator to prevent the unauthorised use of SQL, while allowing existing charts that use SQL to be duplicated.
    attr_accessor :can_dangerously_use_sql

    DEFAULT_CONFIG = [
      {
        "id" => "7cec5a7a-7bf7-403f-b15e-b2e45944182c",
        "title" => "Dashboard 1",
        "children" => [
          {
            "id" => "7cec5a7a-7bf7-403f-b15e-b2e45944182d",
            "type" => "line",
            "title" => "Visits and Checkouts",
            "time_series" => "weekly",

            "verified" => true,
            "unique_visits" => true,
            "visit_tracking" => "any",

            "datasets" => [
              {
                "id" => "7cec5a7a-7bf7-403f-b15e-b2e45944182e",
                "label" => "Visits",
                "type" => "visits",
              },
            ],
          },
        ],
      },
    ]

    def chart_data(filters, config_override: nil, chart_id: nil)
      saved_chart_config = find_chart_by_id(chart_id) unless chart_id.nil?

      combined_config = {
        **saved_chart_config,
        **config_override,
      }

      return DashboardQuery.chart_query(combined_config, filters)
    end

    private def find_chart_by_id(chart_id) = find_item_by_id(configuration, chart_id)

    private def find_item_by_id(items, id)
      items.each do |item|
        return item if item["id"] == id

        if item["children"].is_a?(Array)
          child_item = find_item_by_id(item["children"], id)
          return child_item unless child_item.nil?
        end
      end

      return nil
    end
  end
end

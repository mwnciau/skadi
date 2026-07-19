module Skadi
  class Dashboard
    DASHBOARD_CONFIG = [
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
                "id" => "visits",
                "label" => "Visits",
                "type" => "visits",
              },
              {
                "id" => "checkouts",
                "label" => "Checkouts",
                "type" => "views",
                "visible" => true,

                "view_path" => "/checkout",
              },
              {
                "id" => "views",
                "label" => "Views",
                "type" => "views",
                "visible" => true,
              },
              {
                "id" => "conversion",
                "label" => "Conversion rate",
                "type" => "percentage",
                "numerator" => "checkouts",
                "denominator" => "visits",
                "axis" => "right",
              },
              # {
              #   "id" => "checkouts1",
              #   "label" => "Checkouts unique",
              #   "type" => "views",
              #   "visible" => true,
              #
              #   "unique_visits" => true,
              #   "split_by" => "verb",
              #
              #   "verified" => true,
              #
              #   "view_path" => "/checkout",
              #   "view_verb" => "PUT",
              #
              #   "visit_tracking" => "any",
              # },
              # {
              #   "id" => "checkouts1",
              #   "label" => "Checkouts",
              #   "type" => "views",
              #   "visible" => false,
              #
              #   "verified" => true,
              #
              #   "view_path" => "/checkout",
              #   "view_verb" => "PUT",
              #
              #   "visit_tracking" => "any",
              # },
              # {
              #   "id" => "views",
              #   "label" => "Checkouts grouped",
              #   "type" => "views",
              #   "visible" => true,
              #
              #   "verified" => true,
              #   "unique_visits" => true,
              #
              #   "view_path" => "/checkout",
              #   "view_verb" => "PUT",
              #
              #   "visit_tracking" => "any",
              # },
            ],
          },
        ],
      },
    ]

    def config
      @config ||= DASHBOARD_CONFIG
    end

    def config=(config)
      @config = config
    end

    def chart_data(chart, filters)
      #chart = find_item_by_id(DASHBOARD_CONFIG, chart_id)

      return DashboardQuery.chart_query(chart, filters) unless chart.nil?
    end

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

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
            "group" => "day",
            "datasets" => [
              {
                "id" => "visits",
                "label" => "Visits",
                "type" => "visits",
                "filters" => {"verified" => true},
              },
              {
                "id" => "checkouts",
                "label" => "Checkouts",
                "type" => "views",
                "visible" => false,
                "filters" => {
                  "verified" => true,
                  "path" => "/checkout",
                  "visit" => {
                    tracked: true,
                  },
                },
              },
              {
                "id" => "conversion",
                "label" => "Conversion rate",
                "type" => "percentage",
                "numerator" => "checkouts",
                "denominator" => "visits",
              },
            ],
          },
        ],
      },
    ]

    def config = DASHBOARD_CONFIG

    def chart_data(chart_id, filters)
      chart = find_item_by_id(DASHBOARD_CONFIG, chart_id)

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

module Skadi
  class DashboardController < ::ApplicationController
    do_not_track! if defined?(do_not_track!)

    DASHBOARD_CONFIG = [
      {
        "name" => "Dashboard 1",
        "children" => [
          {
            "id" => "7cec5a7a-7bf7-403f-b15e-b2e45944182d",
            "type" => "line",
            "group" => "day",
            "datasets" => [
              {
                "name" => "Visits",
                "type" => "visit",
                "filters" => {"verified" => true},
              },
              {
                "name" => "Views",
                "type" => "views",
                "filters" => {"verified" => true},
              },
            ],
          },
        ],
      },
    ]

    GROUPINGS = {
      "day" => "DATE(created_at)"
    }

    def show
      render :show
    end

    def data
      chart_id = params[:chart_id]
      chart = DASHBOARD_CONFIG["children"].find { |it| it["id"] == chart_id }

      data = Skadi::Visit
        .group(GROUPINGS[chart["group"] || GROUPINGS["day"])
        .where("created_at > ?", 90.days.ago)
        .count
        .map { |date, count| { date: date, count: count } }

      render json: data
    end
  end
end

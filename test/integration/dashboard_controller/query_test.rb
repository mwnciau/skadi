require_relative "test_case"

module Skadi::Integration
  module DashboardController
    class QueryTest < TestCase
      DATES = (11..20).map { |it| "2020-01-#{it} 09:13" }

      DATE_TEST_CASES = [
        {count: 10},
        {count: 5, date_from: "2020-01-16"},
        {count: 5, date_to: "2020-01-15"},
        {count: 5, date_from: "2020-01-12", date_to: "2020-01-16"},
        {count: 1, date_from: "2020-01-13", date_to: "2020-01-13"},
        {count: 0, date_from: "2020-01-01", date_to: "2020-01-05"},
        {count: 0, date_from: "2020-01-16", date_to: "2020-01-12"},
      ]

      test "url date" do
        DATES.each { |date| create :visit, created_at: date }

        chart = build_chart.to_json

        DATE_TEST_CASES.each do |testcase|
          assert_results testcase[:count], configuration: chart, **testcase.except(:count)
        end

        # Uniquely here invalid values are ignored rather than causing errors or undefined behaviour
        assert_results 10, configuration: chart, date_from: "2020-01-01", date_to: "invalid"
        assert_results 10, configuration: chart, date_from: "invalid", date_to: "2020-01-31"
      end

      test "chart date" do
        DATES.each { |date| create :visit, created_at: date }

        DATE_TEST_CASES.each do |testcase|
          chart = build_chart(**testcase.except(:count)).to_json
          assert_results testcase[:count], configuration: chart
        end
      end

      test "dataset date" do
        DATES.each { |date| create :visit, created_at: date }

        DATE_TEST_CASES.each do |testcase|
          chart = build_chart(dataset: build_dataset(**testcase.except(:count))).to_json
          assert_results testcase[:count], configuration: chart
        end
      end

      test "combined dates" do
        DATES.each { |date| create :visit, created_at: date }

        [
          {count: 10},
          {count: 9, url: {date_from: "2020-01-12"}},
          {count: 8, url: {date_from: "2020-01-12"}, chart: {date_to: "2020-01-19"}},
          {count: 7, url: {date_from: "2020-01-12"}, chart: {date_to: "2020-01-19"}, dataset: {date_from: "2020-01-13"}},
          {count: 6, url: {date_from: "2020-01-12", date_to: "2020-01-18"}, chart: {date_to: "2020-01-19"}, dataset: {date_from: "2020-01-13"}},
          {count: 5, url: {date_from: "2020-01-12", date_to: "2020-01-18"}, chart: {date_from: "2020-01-14", date_to: "2020-01-19"}, dataset: {date_from: "2020-01-13"}},
          {count: 4, url: {date_from: "2020-01-12", date_to: "2020-01-18"}, chart: {date_from: "2020-01-14", date_to: "2020-01-19"}, dataset: {date_from: "2020-01-13", date_to: "2020-01-17"}},
          {count: 3, chart: {date_from: "2020-01-15"}, dataset: {date_to: "2020-01-17"}},
          {count: 2, url: {date_from: "2020-01-16"}, dataset: {date_to: "2020-01-17"}},
          {count: 1, chart: {date_from: "2020-01-17"}, dataset: {date_to: "2020-01-17"}},
        ].each do |testcase|
          chart = build_chart(**(testcase[:chart] || {}), dataset: build_dataset(**(testcase[:dataset] || {}))).to_json

          assert_results testcase[:count], configuration: chart, **(testcase[:url] || {})
        end
      end

      test "chart time_series" do
        DATES.each { |date| create :visit, created_at: date }

        none = build_chart(time_series: nil)
        daily = build_chart(time_series: "daily")
        weekly = build_chart(time_series: "weekly")
        monthly = build_chart(time_series: "monthly")

        results = results_for_chart(none)
        assert_equal 1, results.length
        assert_equal({"id" => "dataset-1", "date" => nil, "split" => nil, "count" => 10}, results[0])

        results = results_for_chart(daily)
        assert_equal 10, results.length
        DATES.each_with_index do |date, index|
          assert_equal({"id" => "dataset-1", "date" => date[0,10], "split" => nil, "count" => 1}, results[index])
        end

        results = results_for_chart(weekly)
        assert_equal 3, results.length
        assert_equal({"id" => "dataset-1", "date" => "2020-01-06", "split" => nil, "count" => 2}, results[0])
        assert_equal({"id" => "dataset-1", "date" => "2020-01-13", "split" => nil, "count" => 7}, results[1])
        assert_equal({"id" => "dataset-1", "date" => "2020-01-20", "split" => nil, "count" => 1}, results[2])

        # Add another visit to span multiple months
        create :visit, created_at: "2020-02-01"

        results = results_for_chart(monthly)
        assert_equal 2, results.length
        assert_equal({"id" => "dataset-1", "date" => "2020-01-01", "split" => nil, "count" => 10}, results[0])
        assert_equal({"id" => "dataset-1", "date" => "2020-02-01", "split" => nil, "count" => 1}, results[1])
      end

      test "chart visit_tracking" do
        create :visit, tracking_token: nil, cookies_enabled: false
        create :visit, tracking_token: TRACKING_TOKEN, cookies_enabled: false
        create :visit, tracking_token: TRACKING_TOKEN, cookies_enabled: true

        nil_chart = build_chart(visit_tracking: nil).to_json
        any_chart = build_chart(visit_tracking: "any").to_json
        anonymity_set_chart = build_chart(visit_tracking: "anonymity_set").to_json
        cookie_chart = build_chart(visit_tracking: "cookie").to_json

        assert_results 3, configuration: nil_chart
        assert_results 2, configuration: any_chart
        assert_results 1, configuration: anonymity_set_chart
        assert_results 1, configuration: cookie_chart
      end

      test "chart verified_visits" do
        verified_visit = create :visit, verified: true
        unverified_visit = create :visit, verified: false

        create :view, visit: verified_visit
        create :view, visit: unverified_visit
        create :view, visit: nil

        create :event, visit: verified_visit
        create :event, visit: unverified_visit
        create :event, visit: nil

        # Visits cannot be connected to demographics so we just make one
        create :demographic, count: 5

        dataset = build_dataset(type: "visits")
        nil_chart = build_chart(verified_visits: nil, dataset:)
        true_chart = build_chart(verified_visits: true, dataset:)
        false_chart = build_chart(verified_visits: false, dataset:)

        # Visits
        assert_results 2, configuration: nil_chart.to_json
        assert_results 2, configuration: false_chart.to_json
        assert_results 1, configuration: true_chart.to_json

        # Views
        dataset["type"] = "views"
        assert_results 3, configuration: nil_chart.to_json
        assert_results 3, configuration: false_chart.to_json
        assert_results 1, configuration: true_chart.to_json

        # Events
        dataset["type"] = "events"
        assert_results 3, configuration: nil_chart.to_json
        assert_results 3, configuration: false_chart.to_json
        assert_results 1, configuration: true_chart.to_json

        # Demographics
        dataset["type"] = "demographics"
        assert_results 5, configuration: nil_chart.to_json
        assert_results 5, configuration: false_chart.to_json
        assert_results 5, configuration: true_chart.to_json
      end

      test "chart unique_by" do
        cookie_visit = create :visit, tracking_token: TRACKING_TOKEN, cookies_enabled: true
        cookie_visit_2 = create :visit, tracking_token: TRACKING_TOKEN, cookies_enabled: true

        anonymity_set_visit = create :visit, tracking_token: TRACKING_TOKEN_2, cookies_enabled: false
        anonymity_set_visit_2 = create :visit, tracking_token: TRACKING_TOKEN_2, cookies_enabled: false

        anonymous_visit = create :visit, tracking_token: nil
        anonymous_visit_2 = create :visit, tracking_token: nil

        visits = [cookie_visit, cookie_visit_2, anonymity_set_visit, anonymity_set_visit_2, anonymous_visit, anonymous_visit_2, nil]

        visits.each do |visit|
          create :view, visit: visit
          create :event, visit: visit
        end

        # Visits cannot be connected to demographics so we just make one
        create :demographic, count: 5

        dataset = build_dataset(type: "visits")
        nil_chart = build_chart(unique_by: nil, dataset:)
        visit_chart = build_chart(unique_by: "visit", dataset:)
        visitor_chart = build_chart(unique_by: "visitor", dataset:)

        # Visits: 6 total visits
        assert_results 6, configuration: nil_chart.to_json
        assert_results 6, configuration: visit_chart.to_json
        # 2 different non-nil tracking tokens
        assert_results 2, configuration: visitor_chart.to_json

        # Views
        dataset["type"] = "views"
        # 7 total views
        assert_results 7, configuration: nil_chart.to_json
        # 6 with a visit
        assert_results 6, configuration: visit_chart.to_json
        # 2 different non-nil tracking tokens
        assert_results 2, configuration: visitor_chart.to_json

        # Events
        dataset["type"] = "events"
        # 7 total events
        assert_results 7, configuration: nil_chart.to_json
        # 6 with a visit
        assert_results 6, configuration: visit_chart.to_json
        # 2 different non-nil tracking tokens
        assert_results 2, configuration: visitor_chart.to_json

        # Demographics: not affected by this setting
        dataset["type"] = "demographics"
        assert_results 5, configuration: nil_chart.to_json
        assert_results 5, configuration: visitor_chart.to_json
        assert_results 5, configuration: visit_chart.to_json
      end

      test "dataset split_by" do
        create :view, verb: "GET", created_at: "2020-01-01"
        create :view, verb: "GET", created_at: "2020-01-02"
        create :view, verb: "POST", created_at: "2020-01-01"
        create :view, verb: "POST", created_at: "2020-01-02"
        create :view, verb: "POST", created_at: "2020-01-02"
        create :view, verb: "PUT", created_at: "2020-01-01"

        dataset = build_dataset
        chart = build_chart(dataset: dataset, time_series: "daily")

        dataset["type"] = "views"
        dataset["split_by"] = ["verb"]

        results = results_for_chart(chart)
        assert_equal 5, results.length
        assert_equal({"id" => "dataset-1", "date" => "2020-01-01", "split" => "GET", "count" => 1}, results[0])
        assert_equal({"id" => "dataset-1", "date" => "2020-01-02", "split" => "GET", "count" => 1}, results[1])
        assert_equal({"id" => "dataset-1", "date" => "2020-01-01", "split" => "POST", "count" => 1}, results[2])
        assert_equal({"id" => "dataset-1", "date" => "2020-01-02", "split" => "POST", "count" => 2}, results[3])
        assert_equal({"id" => "dataset-1", "date" => "2020-01-01", "split" => "PUT", "count" => 1}, results[4])
      end

      test "dataset string filter" do
        create :demographic, name: "demographic 1", count: 1, value: "value 1"
        create :demographic, name: "demographic 1", count: 2, value: "value 2"
        create :demographic, name: "demographic 2", count: 4

        dataset = build_dataset(type: "demographics")
        chart = build_chart(dataset: dataset)

        assert_results 7, configuration: chart.to_json

        dataset["name"] = "demographic 1"
        assert_results 3, configuration: chart.to_json

        dataset["name"] = "demographic 2"
        assert_results 4, configuration: chart.to_json

        dataset["name"] = "demographic"
        assert_results 0, configuration: chart.to_json

        dataset["name"] = "demographic 1"
        dataset["value"] = "value 1"
        assert_results 1, configuration: chart.to_json
      end

      test "dataset string filter with sql" do
        create :visit, referrer: "example.com/something"
        create :visit, referrer: "example.com/"
        create :visit, referrer: "example.com/something-else"
        create :visit, referrer: "other.example.com/something-new"

        dataset = build_dataset(type: "visits")
        chart = build_chart(dataset: dataset)

        assert_results 4, configuration: chart.to_json

        dataset["referrer_domain"] = "example.com"
        assert_results 3, configuration: chart.to_json

        dataset["referrer_domain"] = "other.example.com"
        assert_results 1, configuration: chart.to_json

        dataset["referrer_domain"] = "invalid.example.com"
        assert_results 0, configuration: chart.to_json
      end

      test "dataset boolean filter" do
        create :view, verified: true
        create :view, verified: true
        create :view, verified: false

        dataset = build_dataset(type: "views")
        chart = build_chart(dataset: dataset)

        assert_results 3, configuration: chart.to_json

        dataset["verified"] = true
        assert_results 2, configuration: chart.to_json

        dataset["verified"] = false
        assert_results 1, configuration: chart.to_json
      end

      test "percentage dataset" do
        dataset = build_dataset(id: "12345")
        percentage_dataset = build_dataset(type: "percentage", numerator: "12345", denominator: "12345")
        chart = build_chart(datasets: [dataset, percentage_dataset])

        assert_equal [{"id" => "12345", "date" => nil, "split" => nil, "count" => 0}], results_for_chart(chart)
      end

      test "self-referential percentage dataset is handled" do
        # This causes the query to be invalid since percentage datasets are skipped
        percentage_dataset = build_dataset(id: "12345", type: "percentage", numerator: "12345", denominator: "12345")
        chart = build_chart(dataset: percentage_dataset)

        assert_equal [], results_for_chart(chart)
      end

      test "sql dataset" do
        dataset = build_dataset(id: "sql", type: "sql")
        chart = build_chart(time_series: "weekly", dataset: dataset)

        dataset["sql"] = "SELECT '2020-01-11' as date, NULL as split, 1 AS count"
        assert_equal [{"id" => "sql", "date" => "2020-01-06", "split" => nil, "count" => 1}], results_for_chart(chart)

        dataset["sql"] =  "SELECT '2020-01-06' as date, NULL as split, 5 AS count UNION ALL SELECT '2020-01-09' as date, NULL as split, 2 AS count"
        assert_equal [{"id" => "sql", "date" => "2020-01-06", "split" => nil, "count" => 7}], results_for_chart(chart)

        dataset["sql"] = "SELECT '2020-01-11' as date, NULL as split, 1 AS count UNION ALL SELECT '2020-01-11' as date, 'one' as split, 2 AS count"
        assert_equal [
          {"id" => "sql", "date" => "2020-01-06", "split" => nil, "count" => 1},
          {"id" => "sql", "date" => "2020-01-06", "split" => "one", "count" => 2},
        ], results_for_chart(chart)
      end

      def results_for_chart(chart)
        get skadi.dashboard_data_path, params: {configuration: chart.to_json}

        assert_response :ok
        return JSON.parse(response.body)
      end

      def assert_results(count, **params)
        get skadi.dashboard_data_path, params: {**params}

        assert_response :ok
        results = JSON.parse(response.body)

        assert_equal count, results.sum { |it| it["count"] }, "Expected to see #{count} results but got #{results[0]["count"]} at #{caller[0]}"
      end
    end
  end
end

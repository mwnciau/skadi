require_relative "test_case"

module Skadi::Integration
  module DashboardController
    class InjectionTest < TestCase
      CHART_ID = "chart"

      INJECTION_STRINGS = [
        "'",
        '"',
        "`",
        %('"'"'"'"),
        "'; DROP TABLE skadi_dashboards --",
        "'; --",
        "/*",
        "' OR 1=1",
        "' OR 1=1",
        "\\'",
        # False apostrophes
        "＇",
        "’",
        "a" * 10_000,
      ]

      OPERATORS = [ "=", ">", ">=", "<=", "<", "!=", "empty", "not empty", "like", "not like" ]

      test "null byte handling" do
        # The SQLite driver treats null bytes as the end of string, so we just check that the error is caught
        dashboard_with_dataset(id: "\u0000")

        post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

        assert_response :unprocessable_content
        assert_equal %({"error":"SQLite3::SQLException: unrecognized token: \\"'\\":\\nSELECT '\\n       ^"}), response.body
      end

      test "url date field" do
        create :visit

        [ :date_from, :date_to ].each do |field|
          INJECTION_STRINGS.each do |value|
            dashboard_with_chart(id: CHART_ID)

            post skadi.dashboard_data_path, params: { :chart_id => CHART_ID, field => value }, as: :json

            # The dashboard should be valid and no exception returned
            assert_response :ok

            # Setting the date fields should return no rows
            assert_equal '{"data":[{"id":"dataset-1","date":null,"split":null,"count":1}]}', response.body
          end
        end
      end

      test "url page field" do
        [ -1, 0, *INJECTION_STRINGS ].each do |value|
          dashboard_with_chart(id: CHART_ID, type: "table")

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID, page: value }, as: :json

          assert_response :ok
          assert_equal '{"data":[],"resultCount":0,"resultOffset":0}', response.body
        end
      end

      test "chart time_series" do
        create :visit

        INJECTION_STRINGS.each do |value|
          dashboard_with_chart(id: CHART_ID, time_series: value)

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_response :unprocessable_content
          assert_see(/The time_series .* is invalid/)
        end
      end

      test "chart date field" do
        create :visit

        [ :date_from, :date_to ].each do |field|
          INJECTION_STRINGS.each do |value|
            dashboard_with_chart(:id => CHART_ID, field => value)

            post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

            # The dashboard should be valid and no exception returned
            assert_response :ok

            # This is a bit of a weird state, but the important thing is there are no SQL errors
            assert_see(/\A\{"data":\[\{"id":"dataset-1","date":null,"split":null,"count":[01]\}\]\}\z/)
          end
        end
      end

      test "dataset id" do
        create :event, created_at: "2020-01-06"

        INJECTION_STRINGS.each do |value|
          dashboard_with_dataset(type: "events", id: value)

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          # The dashboard should be valid and no exception returned
          assert_response :ok

          # Setting the id shouldn't affect the rows being returned
          assert_see '"date":"2020-01-06","split":null,"count":1}]'
        end
      end

      test "dataset count_by" do
        create :event, created_at: "2020-01-06"

        INJECTION_STRINGS.each do |value|
          dashboard_with_dataset(type: "events", count_by: value)

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          # The dashboard should be valid and no exception returned
          assert_response :ok

          # Setting the count_by shouldn't affect the rows being returned
          assert_see '"date":"2020-01-06","split":null,"count":1}]'
        end
      end

      test "dataset split_by" do
        create :event, created_at: "2020-01-06"

        dashboard_with_dataset(type: "events", split_by: INJECTION_STRINGS)

        post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

        # The dashboard should be valid and no exception returned
        assert_response :ok

        # Setting the split_by shouldn't affect the rows being returned
        assert_see '"date":"2020-01-06","split":null,"count":1}]'
      end

      test "dataset belongs_to" do
        create :event, created_at: "2020-01-06"

        INJECTION_STRINGS.each do |value|
          [
            value,
            { visits: value },
            { value => {} },
            { visits: { required: value } },
            { visits: { split_by: value } },
            { visits: { split_by: [value] } },
            { visits: { filters: value } },
            { visits: { filters: [value] } },
            { visits: { filters: [ { field: value, operator: "=", value: "" } ] } },
          ].each do |belongs_to|
            dashboard_with_dataset(type: "events", belongs_to: belongs_to)

            post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

            assert_response :ok
            assert_see(/\A\{"data":\[/)
          end
        end

        INJECTION_STRINGS.each do |value|
          dashboard_with_dataset(type: "events", belongs_to: { visits: { filters: [ { field: "utm_source", operator: value, value: "" } ] } })

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_response :unprocessable_content
          assert_see '{"error":"Unknown operator'
        end

        INJECTION_STRINGS.each do |value|
          dashboard_with_dataset(type: "events", belongs_to: { visits: { filters: [ { field: "utm_source", operator: "=", value: value } ] } })

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_response :ok
          assert_equal '{"data":[]}', response.body
        end
      end

      test "dataset field with sql" do
        create :visit

        INJECTION_STRINGS.each do |value|
          dashboard_with_dataset(type: "visits", filters: OPERATORS.map { |operator| { field: "referrer_domain", operator:, value: } })

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_response :ok
          assert_equal '{"data":[]}', response.body
        end
      end

      test "dataset filter fields" do
        INJECTION_STRINGS.each do |field|
          dashboard_with_dataset(type: "views", filters: [ { field:, operator: "=", value: "1" } ])

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_response :ok
          assert_equal '{"data":[]}', response.body
        end
      end

      test "dataset filter operators" do
        INJECTION_STRINGS.each do |operator|
          dashboard_with_dataset(type: "views", filters: [ { field: "verified", operator:, value: 1 } ])

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_see "Unknown operator"
        end
      end

      test "dataset filter boolean field" do
        create :view

        INJECTION_STRINGS.each do |value|
          dashboard_with_dataset(type: "views", filters: OPERATORS.map { |operator| { field: "verified", operator:, value: } })

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_response :ok
          assert_equal '{"data":[]}', response.body
        end
      end

      test "dataset filter date field" do
        create :event

        INJECTION_STRINGS.each do |value|
          dashboard_with_dataset(type: "events", filters: OPERATORS.map { |operator| { field: "date", operator:, value: } })

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_response :ok
          assert_equal '{"data":[]}', response.body
        end
      end

      test "dataset filter number field" do
        create :demographic

        INJECTION_STRINGS.each do |value|
          dashboard_with_dataset(type: "demographics", filters: OPERATORS.map { |operator| { field: "count", operator:, value: } })

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_response :ok
          assert_equal '{"data":[]}', response.body
        end
      end


      test "dataset filter string field" do
        create :visit

        INJECTION_STRINGS.each do |value|
          dashboard_with_dataset(type: "visits", filters: OPERATORS.map { |operator| { field: "utm_source", operator:, value: } })

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_response :ok
          assert_equal '{"data":[]}', response.body
        end
      end

      test "dataset filter string with options field" do
        create :view

        INJECTION_STRINGS.each do |value|
          dashboard_with_dataset(type: "views", filters: OPERATORS.map { |operator| { field: "verb", operator:, value: } })

          post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

          assert_response :ok
          assert_equal '{"data":[]}', response.body
        end
      end

      test "sql dataset with obvious side effects" do
        # We are just testing that obvious SQL with side effects is blocked, e.g. UPDATE or DELETE statements. The reason the sql dataset type is dangerous is because functions can have real side-effects and it's not feasible to detect and block them without writing a full SQL parser, which we're not going to do. The risk is on the developer who dangerously enabled SQL.
        create :visit

        dashboard_with_dataset(type: "sql", sql: "DELETE FROM skadi_visits WHERE 1=1 OR 1='date split count'")

        post skadi.dashboard_data_path, params: { chart_id: CHART_ID }, as: :json

        # The side effect should not have run
        assert_equal 1, Skadi::Visit.count

        assert_response :unprocessable_content
        assert_see "SQLException"
      end

      # This method bypasses validation allowing us to test dashboard data endpoint, not the validation
      private def dashboard_with_dataset(**dataset_options)
        Skadi::Dashboard.delete_all
        dashboard = build_dashboard(tab: build_tab(chart: build_chart(id: CHART_ID, time_series: "weekly", dataset: build_dataset(**dataset_options))))
        dashboard.save!(validate: false)

        return dashboard
      end

      # This method bypasses validation allowing us to test dashboard data endpoint, not the validation
      private def dashboard_with_chart(**chart_options)
        Skadi::Dashboard.delete_all
        dashboard = build_dashboard(tab: build_tab(chart: build_chart(**chart_options)))
        dashboard.save!(validate: false)

        return dashboard
      end
    end
  end
end

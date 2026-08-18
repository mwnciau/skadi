require_relative "test_case"
require "helpers/dashboard_configuration_helper"

module Skadi::Unit
  class DashboardValidatorTest < TestCase
    include Helpers::DashboardConfigurationHelper

    VALID_SQL = "SELECT created_at as date, empty as split, 1 as count FROM skadi_visits"

    ##############################
    #        Happy paths         #
    ##############################

    test "the app's default configuration is valid" do
      dashboard = build_dashboard(Skadi::Dashboard.default_configuration)

      assert dashboard.validate!
    end

    test "valid visits dataset" do
      views_dataset = build_dataset(
        type: "visits",
        visible: false,
        axis: "right",

        split_by: [ "referrer_domain" ],
        filters: [
          { field: "date", operator: ">=", value: "2020-01-01" },
          { field: "date", operator: "<=", value: "2020-12-31" },
          { field: "landing_page", operator: "=", value: "landing_page" },
          { field: "referrer_domain", operator: "!=", value: "referrer_domain" },
          { field: "utm_source", operator: "empty" },
          { field: "utm_medium", operator: "not empty" },
          { field: "utm_term", operator: "like", value: "utm_term" },
          { field: "utm_content", operator: "not like", value: "utm_content" },
          { field: "utm_campaign", operator: "=", value: "utm_campaign" },
        ],
      )

      assert build_dashboard([ build_tab(children: [ build_chart(datasets: [ views_dataset ]) ]) ]).validate!
    end

    test "valid minimal visits dataset" do
      visits_dataset = build_dataset(type: "visits")

      assert build_dashboard([ build_tab(children: [ build_chart(datasets: [ visits_dataset ]) ]) ]).validate!
    end

    test "valid views dataset" do
      views_dataset = build_dataset(
        type: "views",
        visible: false,
        axis: "right",

        split_by: %w[controller action],

        filters: [
          { field: "date", operator: ">=", value: "2020-01-01" },
          { field: "date", operator: "<=", value: "2020-12-31" },
          { field: "action", operator: "=", value: "action" },
          { field: "controller", operator: "!=", value: "controller" },
          { field: "path", operator: "empty" },
          { field: "verb", operator: "=", value: "GET" },
          { field: "version", operator: "like", value: "version" },
        ],
      )

      assert build_dashboard([ build_tab(children: [ build_chart(datasets: [ views_dataset ]) ]) ]).validate!
    end

    test "valid minimal views dataset" do
      views_dataset = build_dataset(type: "views")

      assert build_dashboard([ build_tab(children: [ build_chart(datasets: [ views_dataset ]) ]) ]).validate!
    end

    test "valid events dataset" do
      events_dataset = build_dataset(
        type: "events",
        visible: false,
        axis: "right",
        filters: [
          { field: "date", operator: ">=", value: "2020-01-01" },
          { field: "date", operator: "<=", value: "2020-12-31" },
          { field: "name", operator: "=", value: "name" },
        ],
      )

      assert build_dashboard([ build_tab(children: [ build_chart(datasets: [ events_dataset ]) ]) ]).validate!
    end

    test "valid minimal events dataset" do
      views_dataset = build_dataset(type: "events")

      assert build_dashboard([ build_tab(children: [ build_chart(datasets: [ views_dataset ]) ]) ]).validate!
    end

    test "valid percentage dataset" do
      dataset_1 = build_dataset(id: "id1")
      dataset_2 = build_dataset(id: "id2")

      percentage_dataset = build_dataset(
        type: "percentage",
        visible: false,
        axis: "right",

        numerator: "id1",
        denominator: "id2",
      )

      assert build_dashboard([ build_tab(children: [ build_chart(datasets: [ dataset_1, percentage_dataset, dataset_2 ]) ]) ]).validate!
    end

    test "valid sql dataset" do
      sql_dataset = build_dataset(
        type: "sql",
        visible: false,
        axis: "right",

        sql: VALID_SQL,
      )
      dashboard = build_dashboard([ build_tab(children: [ build_chart(datasets: [ sql_dataset ]) ]) ])
      dashboard.can_dangerously_use_sql = true

      assert dashboard.validate!
    end

    ##############################
    #       Tab validation       #
    ##############################

    test "validates configuration is an array" do
      assert_configuration_error("configuration must be an array", {})
    end

    test "validates configuration must have one element" do
      assert_configuration_error("configuration must have at least one element", [])
    end

    test "validates tab is a hash" do
      assert_configuration_error("configuration[0] must be a hash", [ "invalid" ])
    end

    test "validates tab id" do
      assert_tab_error("id must be a string", id: 123)
    end

    test "validates tab title" do
      assert_tab_error("title must be a string", title: 4.1)
    end

    test "validates tab description" do
      assert_tab_error("description must be a string", description: [])
    end

    test "validates tab date_from" do
      assert_tab_error("date_from must be a date", date_from: 12341532532)
    end

    test "validates tab date_to" do
      assert_tab_error("date_to must be a date", date_to: "25/12/2020")
    end

    test "validates tab children" do
      assert_tab_error("children must be an array", children: {})
    end

    test "validates tab unknown key" do
      assert_tab_error("bogus is not a valid key", bogus: :value)
    end

    ##############################
    #      Chart validation      #
    ##############################

    test "validates chart is a hash" do
      assert_tab_error("children[0] must be a hash", children: [ nil ])
    end

    CHART_FIELDS = {
      id: :string,
      title: :string,
      date_from: :date,
      date_to: :date,
      verified_visits: :boolean,
    }
    CHART_FIELDS.each do |field, type|
      test "validates chart #{field}" do
        assert_chart_error("#{field} must be a #{type}", field => 1)
      end
    end

    test "validates chart type" do
      assert_chart_error('type "pie" must be one of', type: "pie")
    end

    test "validates chart unique_by" do
      assert_chart_error('unique_by "pie" must be one of', unique_by: "pie")
    end

    test "validates chart time_series" do
      assert_chart_error('time_series "yearly" must be one of', time_series: "yearly")
    end

    test "validates chart visit_tracking" do
      assert_chart_error("visit_tracking [] must be one of", visit_tracking: [])
    end

    test "validates chart datasets is an array" do
      assert_chart_error("datasets must be an array", datasets: {})
    end

    test "validates chart has a dataset" do
      assert_chart_error("datasets must have at least one element", datasets: [])
    end

    test "validates chart unknown key" do
      assert_chart_error("bogus is not a valid key", bogus: :value)
    end

    test "validates table has one dataset" do
      assert_chart_error("datasets must have one dataset for the table type", type: "table", datasets: [ 1, 2 ])
    end

    test "validates table dataset cannot be percentage" do
      assert_chart_error("datasets[0].type cannot be percentage for the table type", type: "table", datasets: [ build_dataset(type: "percentage") ])
    end

    ##############################
    #     Dataset validation     #
    ##############################

    test "validates dataset is a hash" do
      assert_chart_error("datasets[0] must be a hash", datasets: [ 0 ])
    end

    COMMON_DATASET_FIELDS = {
      id: :string,
      label: :string,
      visible: :boolean,
    }
    COMMON_DATASET_FIELDS.each do |field, type|
      test "validates visit dataset #{field}" do
        assert_dataset_error("#{field} must be a #{type}", field => 1)
      end
    end

    test "validates dataset axis" do
      assert_dataset_error("axis false must be one of", axis: false)
    end

    test "validates dataset type" do
      assert_dataset_error("type is not a valid dataset type", type: "custom")
    end

    test "validates dataset unknown key" do
      assert_dataset_error("bogus is not a valid key", bogus: :value)
    end

    test "validates dataset split_by" do
      assert_dataset_error("split_by must be an array", split_by: "pie")
      assert_dataset_error('split_by[0] "pie" must be one of', split_by: [ "pie" ])
      assert_dataset_error("split_by[0] nil must be one of", split_by: [ nil ])
    end

    test "validates dataset filter" do
      assert_dataset_error("filters must be an array", filters: false)
      assert_dataset_error("filters[0] must be a Hash", filters: [ 1 ])
      assert_dataset_error("filters[0].field must be one of ", filters: [ {} ])
      assert_dataset_error("filters[0].field must be one of ", filters: [ { field: 1 } ])
      assert_dataset_error("filters[0].operator must be one of ", filters: [ { field: "utm_source" } ])
      assert_dataset_error("filters[0].operator must be one of ", filters: [ { field: "utm_source", operator: "cake" } ])
      assert_dataset_error("filters[0].value must be set", filters: [ { field: "utm_source", operator: "=" } ])
      assert_dataset_error("filters[0].value must be set", filters: [ { field: "utm_source", operator: "=", value: nil } ])
    end

    test "validates dataset boolean filter" do
      [ 1, 3.14, "true", {}, [], "false" ].each do |value|
        [ "=", "!=" ].each do |operator|
          filters = [ { field: "verified", operator:, value: } ]

          assert_dataset_error("filters[0].value must be a boolean", type: "views", filters:)
        end
      end

      [ "empty", "not empty" ].each do |operator|
        filters = [ { field: "date", operator:, value: "something" } ]

        assert_dataset_error("filters[0].value is not a valid key", filters:)
      end
    end

    test "validates dataset date filter" do
      [ 1, 3.14, "true", {}, [], false, "9999-99-99" ].each do |value|
        [ "=", ">", ">=", "<=", "<", "!=" ].each do |operator|
          filters = [ { field: "date", operator:, value: } ]

          assert_dataset_error("filters[0].value must be a date", filters:)
        end
      end

      [ "empty", "not empty" ].each do |operator|
        filters = [ { field: "date", operator:, value: "something" } ]

        assert_dataset_error("filters[0].value is not a valid key", filters:)
      end
    end

    test "validates dataset number filter" do
      [ true, false, "true", {}, [], "false", "12" ].each do |value|
        [ "=", ">", ">=", "<=", "<", "!=" ].each do |operator|
          filters = [ { field: "count", operator:, value: } ]

          assert_dataset_error("filters[0].value must be a number", type: "demographics", filters:)
        end
      end

      [ "empty", "not empty" ].each do |operator|
        filters = [ { field: "count", operator:, value: "something" } ]

        assert_dataset_error("filters[0].value is not a valid key", type: "demographics", filters:)
      end
    end

    test "validates dataset one of filter" do
      [ 1, 3.14, true, {}, [], false ].each do |value|
        [ "=", "!=" ].each do |operator|
          filters = [ { field: "verb", operator:, value: } ]

          assert_dataset_error("filters[0].value #{value.inspect} must be one of", type: "views", filters:)
        end
      end

      [ "empty", "not empty" ].each do |operator|
        filters = [ { field: "date", operator:, value: "something" } ]

        assert_dataset_error("filters[0].value is not a valid key", filters:)
      end
    end

    test "validates dataset string filter" do
      [ 1, 3.14, true, {}, [], false ].each do |value|
        [ "=", "!=", "like", "not like" ].each do |operator|
          filters = [ { field: "utm_source", operator:, value: } ]

          assert_dataset_error("filters[0].value must be a string", filters:)
        end
      end

      [ "empty", "not empty" ].each do |operator|
        filters = [ { field: "date", operator:, value: "something" } ]

        assert_dataset_error("filters[0].value is not a valid key", filters:)
      end
    end

    test "validates only fields marked with filter: true can be filtered" do
      assert_dataset_error("filters[0].field must be one of ", type: "views", filters: [ { field: "controller_action" } ])
    end

    test "validates only fields marked with split: true can be split" do
      assert_dataset_error('split_by[0] "action" must be one of ', type: "views", split_by: ["action"])
    end

    ##############################
    #   SQL dataset validation   #
    ##############################

    test "validates sql when use is permitted" do
      dashboard = build_dashboard([ build_tab(children: [ build_chart(
        datasets: [ build_dataset(type: "sql", sql: 123) ],
      ) ]) ])
      dashboard.can_dangerously_use_sql = true

      refute dashboard.valid?
      assert_match "sql must be a string", dashboard.errors.full_messages.join
    end

    test "validates sql required fields are in sql" do
      dashboard = build_dashboard([ build_tab(children: [ build_chart(
        datasets: [ build_dataset(type: "sql", sql: "invalid sql") ],
      ) ]) ])
      dashboard.can_dangerously_use_sql = true

      refute dashboard.valid?
      assert_match "sql must include the fields date, split and count", dashboard.errors.full_messages.join

      dashboard.configuration[0]["children"][0]["datasets"][0]["sql"] = "date split count"

      assert dashboard.validate!
    end

    test "validates sql when use is not permitted" do
      dashboard = build_dashboard([ build_tab(children: [ build_chart(
        datasets: [ build_dataset(type: "sql", sql: VALID_SQL) ],
      ) ]) ])

      refute dashboard.valid?
      assert_match "sql cannot be modified", dashboard.errors.full_messages.join
    end

    test "allows sql when use is not permitted after save" do
      dashboard = build_dashboard([ build_tab(children: [ build_chart(
        datasets: [ build_dataset(type: "sql", sql: VALID_SQL) ],
      ) ]) ])

      refute dashboard.valid?

      dashboard.save(validate: false)

      assert dashboard.validate!
    end

    test "validates sql may be copied when use is not permitted" do
      dashboard = build_dashboard([ build_tab(children: [ build_chart(
        datasets: [ build_dataset(type: "sql", sql: VALID_SQL) ],
      ) ]) ])
      dashboard.can_dangerously_use_sql = true
      dashboard.save!

      # Insert a duplicate dataset with the same SQL
      dashboard.configuration[0]["children"][0]["datasets"] << build_dataset(:type => "sql", "sql" => VALID_SQL)
      dashboard.can_dangerously_use_sql = false

      assert dashboard.validate!
    end

    test "validates sql dataset unknown key" do
      assert_dataset_error("numerator is not a valid key", numerator: "numerator", type: "sql")
    end

    #################################
    # Percentage dataset validation #
    #################################

    test "validates percentage dataset numerator" do
      assert_dataset_error("numerator must be a dataset id", numerator: 1, type: "percentage")
    end

    test "validates percentage dataset denominator" do
      assert_dataset_error("denominator must be a dataset id", denominator: "12345", type: "percentage")
    end

    test "validates percentage dataset numerator/denominator only match datasets within the same chart" do
      other_chart_datasets = [ build_dataset(id: "a", type: "visits") ]
      this_chart_datasets = [ build_dataset(id: "pct", type: "percentage", numerator: "a", denominator: "a") ]

      dashboard = build_dashboard([ build_tab(children: [
        build_chart(id: "chart-1", datasets: other_chart_datasets),
        build_chart(id: "chart-2", datasets: this_chart_datasets),
      ]) ])

      refute dashboard.valid?
      errors = dashboard.errors[:configuration].join
      assert_match "configuration[0].children[1].datasets[0].numerator must be a dataset id", errors
      assert_match "configuration[0].children[1].datasets[0].denominator must be a dataset id", errors
    end

    test "validates percentage dataset unknown key" do
      assert_dataset_error("sql is not a valid key", sql: "sql", type: "percentage")
    end

    ##############################
    #       Helper methods       #
    ##############################

    private def assert_configuration_error(error, configuration)
      dashboard = build_dashboard(configuration)

      refute dashboard.valid?, "Expected the dashboard configuration to be invalid"
      assert_includes dashboard.errors[:configuration].join, error
    end

    private def assert_tab_error(error, **tab_config)
      assert_configuration_error("configuration[0].#{error}", [ build_tab(**tab_config) ])
    end

    private def assert_chart_error(error, **chart_config)
      assert_tab_error("children[0].#{error}", children: [ build_chart(**chart_config) ])
    end

    private def assert_dataset_error(error, **dataset_config)
      assert_chart_error("datasets[0].#{error}", datasets: [ build_dataset(**dataset_config) ])
    end
  end
end

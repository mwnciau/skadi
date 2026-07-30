require_relative "test_case"

module Skadi::Unit
  class DashboardValidatorTest < TestCase
    ##############################
    #        Happy paths         #
    ##############################

    test "the app's default configuration is valid" do
      assert dashboard(Skadi::Dashboard::DEFAULT_CONFIG).valid?
    end

    test "valid visits dataset" do
      views_dataset = dataset(
        type: "visits",
        visible: false,
        axis: "right",

        date_from: "2020-01-01",
        date_to: "2020-12-31",

        split_by: "referrer",

        visit_landing_page: "landing_page",
        visit_referrer_domain: "referrer_domain",

        visit_utm_source: "utm_source",
        visit_utm_medium: "utm_medium",
        visit_utm_term: "utm_term",
        visit_utm_content: "utm_content",
        visit_utm_campaign: "utm_campaign",
      )

      assert dashboard([tab(children: [chart(datasets: [views_dataset])])]).valid?
    end

    test "valid minimal visits dataset" do
      visits_dataset = dataset(type: "visits")

      assert dashboard([tab(children: [chart(datasets: [visits_dataset])])]).valid?
    end

    test "valid views dataset" do
      views_dataset = dataset(
        type: "views",
        visible: false,
        axis: "right",

        date_from: "2020-01-01",
        date_to: "2020-12-31",

        split_by: "controller",

        view_action: "action",
        view_controller: "controller",
        view_path: "path",
        view_verb: "verb",
        view_version: "version",
      )

      assert dashboard([tab(children: [chart(datasets: [views_dataset])])]).valid?
    end

    test "valid minimal views dataset" do
      views_dataset = dataset(type: "views")

      assert dashboard([tab(children: [chart(datasets: [views_dataset])])]).valid?
    end

    test "valid events dataset" do
      events_dataset = dataset(
        type: "events",
        visible: false,
        axis: "right",

        date_from: "2020-01-01",
        date_to: "2020-12-31",

        split_by: "name",

        event_name: "name"
      )

      assert dashboard([tab(children: [chart(datasets: [events_dataset])])]).valid?
    end

    test "valid minimal events dataset" do
      views_dataset = dataset(type: "events")

      assert dashboard([tab(children: [chart(datasets: [views_dataset])])]).valid?
    end

    test "valid percentage dataset" do
      dataset_1 = dataset(id: "id1")
      dataset_2 = dataset(id: "id2")

      percentage_dataset = dataset(
        type: "percentage",
        visible: false,
        axis: "right",

        numerator: "id1",
        denominator: "id2",
      )

      assert dashboard([tab(children: [chart(datasets: [dataset_1, percentage_dataset, dataset_2])])]).valid?
    end

    test "valid sql dataset" do
      sql_dataset = dataset(
        type: "sql",
        visible: false,
        axis: "right",

        sql: "SELECT * FROM skadi_visits",
      )
      d = dashboard([tab(children: [chart(datasets: [sql_dataset])])])
      d.can_dangerously_use_sql = true

      assert d.valid?
    end


    ##############################
    #       Tab validation       #
    ##############################

    test "validates configuration is an array" do
      assert_configuration_error("configuration must be an array", {})
    end

    test "validates tab is a hash" do
      assert_configuration_error("configuration[0] must be a hash", ["invalid"])
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
      assert_tab_error("children[0] must be a hash", children: [nil])
    end

    CHART_FIELDS = {
      id: :string,
      title: :string,
      date_from: :date,
      date_to: :date,
      verified: :boolean,
      unique_visits: :boolean,
    }
    CHART_FIELDS.each do |field, type|
      test "validates chart #{field}" do
        assert_chart_error("#{field} must be a #{type}", field => 1)
      end
    end

    test "validates chart type" do
      assert_chart_error("type must be one of", type: "pie")
    end

    test "validates chart time_series" do
      assert_chart_error("time_series must be one of", time_series: "yearly")
    end

    test "validates chart visit_tracking" do
      assert_chart_error("visit_tracking must be one of", visit_tracking: [])
    end

    test "validates chart datasets" do
      assert_chart_error("datasets must be an array", datasets: {})
    end

    test "validates chart unknown key" do
      assert_chart_error("bogus is not a valid key", bogus: :value)
    end

    ##############################
    #     Dataset validation     #
    ##############################

    test "validates dataset is a hash" do
      assert_chart_error("datasets[0] must be a hash", datasets: [0])
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
      assert_dataset_error("axis must be one of", axis: false)
    end

    test "validates dataset type" do
      assert_dataset_error("type must be one of", type: "custom")
    end

    test "validates dataset unknown key" do
      assert_dataset_error("bogus is not a valid key", bogus: :value)
    end

    ###############################
    #  Visits dataset validation  #
    ###############################

    VISITS_DATASET_FIELDS = {
      date_from: :date,
      date_to: :date,
      visit_landing_page: :string,
      visit_referrer_domain: :string,
      visit_utm_source: :string,
      visit_utm_medium: :string,
      visit_utm_term: :string,
      visit_utm_content: :string,
      visit_utm_campaign: :string,
    }
    VISITS_DATASET_FIELDS.each do |field, type|
      test "validates visits dataset #{field}" do
        assert_dataset_error("#{field} must be a #{type}", field => 1, type: "visits")
      end
    end

    test "validates visits dataset split_by" do
      assert_dataset_error("split_by must be one of", split_by: "controller", type: "visits")
    end

    test "validates visits dataset unknown key" do
      assert_dataset_error("event_name is not a valid key", event_name: "name", type: "visits")
    end

    ##############################
    #  Views dataset validation  #
    ##############################

    VIEWS_DATASET_FIELDS = {
      date_from: :date,
      date_to: :date,
      view_action: :string,
      view_controller: :string,
      view_path: :string,
      view_verb: :string,
      view_version: :string,
    }
    VIEWS_DATASET_FIELDS.each do |field, type|
      test "validates views dataset #{field}" do
        assert_dataset_error("#{field} must be a #{type}", field => 1, type: "views")
      end
    end

    test "validates views dataset split_by" do
      assert_dataset_error("split_by must be one of", split_by: "referrer", type: "views")
    end

    test "validates views dataset unknown key" do
      assert_dataset_error("visit_utm_source is not a valid key", visit_utm_source: "source", type: "views")
    end

    ###############################
    #  Events dataset validation  #
    ###############################

    EVENTS_DATASET_FIELDS = {
      date_from: :date,
      date_to: :date,
      event_name: :string,
    }
    EVENTS_DATASET_FIELDS.each do |field, type|
      test "validates events dataset #{field}" do
        assert_dataset_error("#{field} must be a #{type}", field => 1, type: "events")
      end
    end

    test "validates events dataset split_by" do
      assert_dataset_error("split_by must be one of", split_by: "version", type: "events")
    end

    test "validates events dataset unknown key" do
      assert_dataset_error("view_action is not a valid key", view_action: "action", type: "events")
    end

    ##############################
    #   SQL dataset validation   #
    ##############################

    test "validates sql when use is permitted" do
      d = dashboard([tab(children: [chart(
        datasets: [dataset(type: "sql", sql: 123)],
      )])])
      d.can_dangerously_use_sql = true

      refute d.valid?
      assert_match "sql must be a string", d.errors.full_messages.join
    end

    test "validates sql when use is not permitted" do
      d = dashboard([tab(children: [chart(
        datasets: [dataset(type: "sql", sql: "SELECT * FROM skadi_visits")],
      )])])

      refute d.valid?
      assert_match "sql cannot be modified", d.errors.full_messages.join
    end

    test "allows sql when use is not permitted after save" do
      d = dashboard([tab(children: [chart(
        datasets: [dataset(type: "sql", sql: "SELECT * FROM skadi_visits")],
      )])])

      refute d.valid?

      d.save(validate: false)

      assert d.valid?
    end

    test "validates sql may be copied when use is not permitted" do
      d = dashboard([tab(children: [chart(
        datasets: [dataset(type: "sql", sql: "SELECT * FROM skadi_visits")],
      )])])
      d.can_dangerously_use_sql = true
      d.save!

      # Insert a duplicate dataset with the same SQL
      d.configuration[0]["children"][0]["datasets"] << dataset(type: "sql", "sql" => "SELECT * FROM skadi_visits")
      d.can_dangerously_use_sql = false

      valid = d.valid?
      assert_equal "", d.errors.full_messages.join
      assert d.valid?
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
      other_chart_datasets = [dataset(id: "a", type: "visits")]
      this_chart_datasets = [dataset(id: "pct", type: "percentage", numerator: "a", denominator: "a")]

      d = dashboard([tab(children: [
        chart(id: "chart-1", datasets: other_chart_datasets),
        chart(id: "chart-2", datasets: this_chart_datasets),
      ])])

      refute d.valid?
      errors = d.errors[:configuration].join
      assert_match "configuration[0].children[1].datasets[0].numerator must be a dataset id", errors
      assert_match "configuration[0].children[1].datasets[0].denominator must be a dataset id", errors
    end

    test "validates percentage dataset unknown key" do
      assert_dataset_error("sql is not a valid key", sql: "sql", type: "percentage")
    end

    ##############################
    #       Helper methods       #
    ##############################

    private def dataset(type: "visits", id: "dataset-1", label: "Dataset", **attrs)
      {"id" => id, "label" => label, "type" => type, **attrs}
    end

    private def chart(id: "chart-1", type: "bar", title: "Chart", datasets: [dataset], **attrs)
      {"id" => id, "type" => type, "title" => title, "datasets" => datasets, **attrs}
    end

    private def tab(id: "tab-1", title: "Tab", children: [chart], **attrs)
      {"id" => id, "title" => title, "children" => children, **attrs}
    end

    private def dashboard(configuration)
      Skadi::Dashboard.new(name: "Test dashboard", configuration: configuration)
    end

    private def assert_configuration_error(error, configuration)
      d = dashboard(configuration)

      refute d.valid?, "Expected the dashboard configuration to be invalid"
      assert_match error, d.errors[:configuration].join
    end

    private def assert_tab_error(error, **tab_config)
      assert_configuration_error("configuration[0].#{error}", [tab(**tab_config)])
    end

    private def assert_chart_error(error, **chart_config)
      assert_tab_error("children[0].#{error}", children: [chart(**chart_config)])
    end

    private def assert_dataset_error(error, **dataset_config)
      assert_chart_error("datasets[0].#{error}", datasets: [dataset(**dataset_config)])
    end
  end
end

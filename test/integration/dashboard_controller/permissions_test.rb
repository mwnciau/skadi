require "integration/test_case"

module Skadi::Integration
  module DashboardController
    class PermissionsTest < TestCase
      SQL_DATASET = {
        "id" => "sql-dataset",
        "label" => "SQL",
        "type" => "sql",
        "sql" => "SELECT * FROM skadi_visits",
      }.freeze

      setup do
        Skadi.configuration.dashboard_view_controller_method = :skadi_dashboard_view
        Skadi.configuration.dashboard_edit_controller_method = :skadi_dashboard_edit
        Skadi.configuration.dashboard_dangerously_use_sql_controller_method = :skadi_dashboard_use_sql
      end

      test "can view with permission" do
        ApplicationController.skadi_dashboard_view = true

        get skadi.dashboard_path

        assert_response :ok
        assert_see "Powered by Skadi"
      end

      test "cannot view without permission" do
        ApplicationController.skadi_dashboard_view = false

        get skadi.dashboard_path

        assert_response :forbidden
      end

      test "cannot view without controller method" do
        Skadi.configuration.dashboard_view_controller_method = nil

        get skadi.dashboard_path

        assert_response :forbidden
      end

      test "can fetch data with permission" do
        ApplicationController.skadi_dashboard_view = true

        dashboard = create :dashboard
        chart_id = dashboard.configuration[0]["children"][0]["id"]

        get skadi.dashboard_data_path(chart_id)

        assert_response :ok
      end

      test "cannot fetch data without permission" do
        ApplicationController.skadi_dashboard_view = false

        dashboard = create :dashboard
        chart_id = dashboard.configuration[0]["children"][0]["id"]

        get skadi.dashboard_data_path(chart_id)

        assert_response :forbidden
      end

      test "cannot fetch data without controller method" do
        Skadi.configuration.dashboard_view_controller_method = nil

        dashboard = create :dashboard
        chart_id = dashboard.configuration[0]["children"][0]["id"]

        get skadi.dashboard_data_path(chart_id)

        assert_response :forbidden
      end

      test "can fetch data for specified configuration with edit permission" do
        ApplicationController.skadi_dashboard_view = true
        ApplicationController.skadi_dashboard_edit = true

        create :view

        dashboard = create :dashboard
        chart_id = dashboard.configuration[0]["children"][0]["id"]
        override = {id: "preview", type: "line", title: "Preview", datasets: [{id: "123", label: "123", type: "views"}]}

        get skadi.dashboard_data_path(chart_id), params: {config: override.to_json}

        assert_response :ok

        # By default, the chart should return visits data, which doesn't exist. Returning a count of 1 signals that the override config is used.
        assert_see '"count":1'
      end

      test "cannot fetch data for specified configuration without edit permission" do
        ApplicationController.skadi_dashboard_view = true
        ApplicationController.skadi_dashboard_edit = false

        create :view

        dashboard = create :dashboard
        chart_id = dashboard.configuration[0]["children"][0]["id"]
        override = {id: "preview", type: "line", title: "Preview", datasets: [{id: "123", label: "123", type: "views"}]}

        get skadi.dashboard_data_path(chart_id), params: {config: override.to_json}

        assert_response :ok

        # By default, the chart should return visits data, which doesn't exist. Returning an empty array signals that the override config is ignored.
        assert_equal "[]", response.body
      end

      test "can preview a new sql dataset with sql permission" do
        ApplicationController.skadi_dashboard_view = true
        ApplicationController.skadi_dashboard_edit = true
        ApplicationController.skadi_dashboard_use_sql = true

        dashboard = create :dashboard
        chart_id = dashboard.configuration[0]["children"][0]["id"]
        override = {"id" => "preview", "type" => "line", "title" => "Preview", "datasets" => [SQL_DATASET]}

        get skadi.dashboard_data_path(chart_id), params: {config: override.to_json}

        assert_response :ok
      end

      test "cannot preview a new sql dataset without sql permission" do
        ApplicationController.skadi_dashboard_view = true
        ApplicationController.skadi_dashboard_edit = true
        ApplicationController.skadi_dashboard_use_sql = false

        dashboard = create :dashboard
        chart_id = dashboard.configuration[0]["children"][0]["id"]
        override = {"id" => "preview", "type" => "line", "title" => "Preview", "datasets" => [SQL_DATASET]}

        get skadi.dashboard_data_path(chart_id), params: {config: override.to_json}

        assert_response :unprocessable_content
        assert_see "Invalid chart configuration"
      end

      test "can see sql errors dataset with sql permission" do
        ApplicationController.skadi_dashboard_view = true
        ApplicationController.skadi_dashboard_edit = true
        ApplicationController.skadi_dashboard_use_sql = true

        sql_dataset = SQL_DATASET.dup
        sql_dataset["sql"] = "SELECT '"

        dashboard = create :dashboard
        chart_id = dashboard.configuration[0]["children"][0]["id"]
        override = {"id" => "preview", "type" => "line", "title" => "Preview", "datasets" => [sql_dataset]}

        get skadi.dashboard_data_path(chart_id), params: {config: override.to_json}

        assert_response :unprocessable_content
        assert_see "SQLException: unrecognized token"
      end

      test "cannot see sql errors dataset without sql permission" do
        ApplicationController.skadi_dashboard_view = true
        ApplicationController.skadi_dashboard_edit = true
        ApplicationController.skadi_dashboard_use_sql = false

        sql_dataset = SQL_DATASET.dup
        sql_dataset["sql"] = "SELECT '"

        dashboard = create :dashboard
        chart_id = dashboard.configuration[0]["children"][0]["id"]
        override = {"id" => "preview", "type" => "line", "title" => "Preview", "datasets" => [sql_dataset]}

        get skadi.dashboard_data_path(chart_id), params: {config: override.to_json}

        assert_response :unprocessable_content
        refute_see "SQLException: unrecognized token"
        assert_see "Invalid chart configuration"
      end

      test "can update with permission" do
        ApplicationController.skadi_dashboard_edit = true

        post skadi.dashboard_update_path, params: {configuration: Skadi::Dashboard.default_configuration}, as: :json

        assert_response :ok
      end

      test "cannot update without permission" do
        ApplicationController.skadi_dashboard_edit = false

        post skadi.dashboard_update_path, params: {configuration: Skadi::Dashboard.default_configuration}, as: :json

        assert_response :forbidden
      end

      test "cannot update without controller method" do
        Skadi.configuration.dashboard_edit_controller_method = nil

        post skadi.dashboard_update_path, params: {configuration: Skadi::Dashboard.default_configuration}, as: :json

        assert_response :forbidden
      end

      test "can update SQL with permission" do
        ApplicationController.skadi_dashboard_edit = true
        ApplicationController.skadi_dashboard_use_sql = true

        dashboard = create :dashboard
        configuration = Skadi::Dashboard.default_configuration
        configuration[0]["children"][0]["datasets"] << SQL_DATASET

        post skadi.dashboard_update_path, params: {configuration:}, as: :json

        assert_response :ok
        assert_equal configuration, dashboard.reload.configuration
      end

      test "can duplicate a SQL dataset without permission" do
        ApplicationController.skadi_dashboard_edit = true
        ApplicationController.skadi_dashboard_use_sql = false

        configuration = Skadi::Dashboard.default_configuration
        configuration[0]["children"][0]["datasets"] << SQL_DATASET
        dashboard = create :dashboard, configuration: configuration

        configuration[0]["children"][0]["datasets"] << SQL_DATASET

        post skadi.dashboard_update_path, params: {configuration:}, as: :json

        assert_response :ok
        assert_equal configuration, dashboard.reload.configuration
      end

      test "cannot add a SQL dataset without permission" do
        ApplicationController.skadi_dashboard_edit = true
        ApplicationController.skadi_dashboard_use_sql = false

        dashboard = create :dashboard
        configuration = Skadi::Dashboard.default_configuration
        configuration[0]["children"][0]["datasets"] << SQL_DATASET

        post skadi.dashboard_update_path, params: {configuration:}, as: :json

        assert_response :unprocessable_content
        assert_see "configuration[0].children[0].datasets[1].sql cannot be modified"
        assert_equal Skadi::Dashboard.default_configuration, dashboard.reload.configuration
      end

      test "cannot edit a SQL dataset without permission" do
        ApplicationController.skadi_dashboard_edit = true
        ApplicationController.skadi_dashboard_use_sql = false

        configuration = Skadi::Dashboard.default_configuration
        configuration[0]["children"][0]["datasets"][0] = SQL_DATASET
        dashboard = create :dashboard, configuration: configuration

        new_configuration = configuration.deep_dup
        new_configuration[0]["children"][0]["datasets"][0]["sql"] = "SELECT * FROM skadi_views"

        post skadi.dashboard_update_path, params: {configuration: new_configuration}, as: :json

        assert_response :unprocessable_content
        assert_see "configuration[0].children[0].datasets[0].sql cannot be modified"
        assert_equal configuration, dashboard.reload.configuration
      end
    end
  end
end

require "integration/test_case"
require "helpers/dashboard_configuration_helper"

module Skadi::Integration
  module DashboardController
    class TestCase < ::Skadi::Integration::TestCase
      include Helpers::DashboardConfigurationHelper

      setup do
        Skadi.configuration.dashboard_view_controller_method = :skadi_dashboard_view
        Skadi.configuration.dashboard_edit_controller_method = :skadi_dashboard_edit
        Skadi.configuration.dashboard_dangerously_use_sql_controller_method = :skadi_dashboard_use_sql

        ApplicationController.skadi_dashboard_view = true
        ApplicationController.skadi_dashboard_edit = true
        ApplicationController.skadi_dashboard_use_sql = true
      end
    end
  end
end

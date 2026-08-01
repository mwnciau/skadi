require_relative "test_case"

module Skadi::Integration
  module DashboardController
    class InjectionTest < TestCase
      setup do
        Skadi.configuration.dashboard_view_controller_method = :skadi_dashboard_view
        Skadi.configuration.dashboard_edit_controller_method = :skadi_dashboard_edit
        Skadi.configuration.dashboard_dangerously_use_sql_controller_method = :skadi_dashboard_use_sql
      end

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
        # null byte
        #"\u0000",
        # False apostrophes
        "＇",
        "’",
        "a" * 10_000,
      ]

      test "null byte handling" do
        chart_configuration = chart(id: "\u0000")

        get skadi.dashboard_data_path, params: {configuration: chart_configuration.to_json}
      end

      test "visit sql injection" do
        create :visit

        base_configuration = {
          "id" => "id",
          "label" => "label",
          "type" => "visits"
        }

        fields = ["id", "label", "visible", "axis", "date_from", "date_to", "split_by", "visit_landing_page", "visit_referrer_domain", "visit_utm_source", "visit_utm_medium", "visit_utm_term", "visit_utm_content", "visit_utm_campaign"]

        assert_nothing_raised do
          fields.each do |field|
            configuration = base_configuration.dup
            configuration[field] = "barometer"

            get skadi.dashboard_data_path, params: {configuration: build_chart(dataset: configuration).to_json}

            expected_status = response.status
            expected_kernel = response_kernel

            INJECTION_STRINGS.each do |value|
              configuration = base_configuration.dup
              configuration[field] = value

              get skadi.dashboard_data_path, params: {configuration: build_chart(dataset: configuration).to_json}

              assert_response expected_status

              assert_equal expected_kernel, response_kernel
            end
          end
        end
      end

      private def response_kernel
        if response.status === 200 && response.body.length > 2
          response_data = JSON.parse(response.body)

          return response_data[0]["count"]
        end

        return response.body
      end
    end
  end
end

module Skadi
  class Dashboard < ApplicationRecord
    class Error < StandardError; end
    class ChartNotFoundError < Error; end
    class UnsupportedDatabaseError < Error; end
    class DatasetConfigurationError < Error; end

    validates_with DashboardValidator

    # Used by the validator to prevent the unauthorised use of SQL, while allowing existing charts that use SQL to be duplicated.
    attr_accessor :can_dangerously_use_sql

    DEFAULT_CONFIGURATION = [
      {
        "id" => "7cec5a7a-7bf7-403f-b15e-b2e45944182c",
        "title" => "Dashboard 1",
        "children" => [
          {
            "id" => "7cec5a7a-7bf7-403f-b15e-b2e45944182d",
            "type" => "line",
            "title" => "Visits and Checkouts",
            "time_series" => "weekly",

            "verified_visits" => true,
            "unique_by" => "visit",
            "visit_tracking" => "any",

            "datasets" => [
              {
                "id" => "7cec5a7a-7bf7-403f-b15e-b2e45944182e",
                "label" => "Visits",
                "type" => "visits",
              }.freeze,
            ].freeze,
          }.freeze,
        ].freeze,
      }.freeze,
    ].freeze

    def self.default_configuration = DEFAULT_CONFIGURATION.deep_dup

    def chart_data(chart_id, filters)
      chart_configuration = find_chart_by_id(chart_id) unless chart_id.nil?

      raise ChartNotFoundError.new("Unable to find chart with id #{chart_id.inspect}") unless chart_configuration

      return DashboardQuery.chart_query(chart_configuration, filters)
    end

    # Returns an array containing the SQL queries in the _persisted_ record - i.e. those that non-permitted users can use/run
    def sql_strings
      return [] unless configuration_was.is_a?(Array)

      charts = configuration_was.flat_map do |tab|
        tab.is_a?(Hash) && tab["children"].is_a?(Array) ? tab["children"] : []
      end
      datasets = charts.flat_map do |chart|
        chart.is_a?(Hash) && chart["datasets"].is_a?(Array) ? chart["datasets"] : []
      end
      return datasets.flat_map do |dataset|
        next [] unless dataset.is_a?(Hash) && dataset["type"] == "sql" && dataset["sql"].is_a?(String)

        [dataset["sql"]]
      end
    end

    private def find_chart_by_id(chart_id) = find_item_by_id(configuration, chart_id)

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

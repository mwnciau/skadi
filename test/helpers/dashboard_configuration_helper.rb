module Helpers
  module DashboardConfigurationHelper
    private def build_dataset(type: "visits", id: "dataset-1", label: "Dataset", **attrs)
      { "id" => id, "label" => label, "type" => type, **attrs }
    end

    private def build_chart(id: nil, type: "bar", title: "Chart", datasets: [ build_dataset ], dataset: nil, **attrs)
      datasets = [ dataset ] unless dataset.nil?
      id ||= ::Random.uuid_v7

      { "id" => id, "type" => type, "title" => title, "datasets" => datasets, **attrs }
    end

    private def build_tab(id: "tab-1", title: "Tab", children: [ build_chart ], chart: nil, **attrs)
      children = [ chart ] unless chart.nil?

      { "id" => id, "title" => title, "children" => children, **attrs }
    end

    private def build_dashboard(configuration = nil, tab: nil)
      configuration = [ tab ] unless tab.nil?

      Skadi::Dashboard.new(name: "Test dashboard", configuration: configuration)
    end
  end
end

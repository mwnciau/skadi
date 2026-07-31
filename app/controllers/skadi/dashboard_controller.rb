module Skadi
  class DashboardController < ::ApplicationController
    do_not_track! if defined?(do_not_track!)

    before_action :set_dashboard
    before_action :set_dashboard_permissions

    def show
      return head :forbidden unless can_view

      render :show, locals: {dashboard_config: @dashboard.configuration, can_edit: can_edit, can_dangerously_use_sql: can_dangerously_use_sql}
    end

    def data
      return head :forbidden unless can_view

      query_filters = params.permit(:date_from, :date_to)

      if can_edit && params[:config].present?
        return custom_chart_data(query_filters)
      end

      return render json: @dashboard.chart_data(params["chart_id"], query_filters.to_h)
    rescue Skadi::DashboardQuery::Error => e
      render json: {error: e.message}, status: :unprocessable_content
    rescue ActiveRecord::StatementInvalid => e
      message = can_dangerously_use_sql ? e.message : "Something went wrong fetching the data. Please contact a site admin."
      render json: {error: message}, status: :unprocessable_content
    end

    def update
      return head :forbidden unless can_edit

      # The dashboard validator will strongly check the structure of :configuration
      @dashboard.configuration = params.to_unsafe_h[:configuration]

      if @dashboard.save
        head :ok
      else
        render json: {error: "Dashboard validation failed. #{@dashboard.errors.full_messages.join("\n")}"}, status: :unprocessable_content
      end
    end

    private def custom_chart_data(query_filters)
      config_override = begin
        JSON.parse(params[:config])
      rescue
        return render json: {error: "Unable to parse chart config"}, status: :unprocessable_content
      end

      config_override["id"] = "chart-with-config-override"
      @dashboard.configuration[0]["children"] << config_override

      unless @dashboard.valid?
        return render json: {error: "Invalid chart configuration"}, status: :unprocessable_content
      end

      return render json: @dashboard.chart_data("chart-with-config-override", query_filters.to_h)
    end

    private def set_dashboard
      @dashboard = Skadi::Dashboard.first_or_create!(name: "Default dashboard", configuration: Skadi::Dashboard.default_configuration)
    end

    private def set_dashboard_permissions
      @dashboard.can_dangerously_use_sql = can_dangerously_use_sql
    end

    private def can_view
      return @can_view if defined?(@can_view)

      return false if Skadi.configuration.dashboard_view_controller_method.nil?
      return false unless respond_to?(Skadi.configuration.dashboard_view_controller_method, true)

      return @can_view = send(Skadi.configuration.dashboard_view_controller_method)
    end

    private def can_edit
      return @can_edit if defined?(@can_edit)

      return false if Skadi.configuration.dashboard_edit_controller_method.nil?
      return false unless respond_to?(Skadi.configuration.dashboard_edit_controller_method, true)

      return @can_edit = send(Skadi.configuration.dashboard_edit_controller_method)
    end

    private def can_dangerously_use_sql
      return @can_dangerously_use_sql if defined?(@can_dangerously_use_sql)

      return false if Skadi.configuration.dashboard_dangerously_use_sql_controller_method.nil?
      return false unless respond_to?(Skadi.configuration.dashboard_dangerously_use_sql_controller_method, true)

      return @can_dangerously_use_sql = send(Skadi.configuration.dashboard_dangerously_use_sql_controller_method)
    end
  end
end

module Skadi
  class DashboardController < ::ApplicationController
    do_not_track! if defined?(do_not_track!)

    before_action :set_dashboard
    before_action :set_dashboard_permissions

    def show
      return head :forbidden unless can_view

      render :show, locals: {
        dashboard_configuration: @dashboard.configuration,
        dataset_schema: Skadi::Schema.frontend_schema,
        can_edit: can_edit,
        can_dangerously_use_sql: can_dangerously_use_sql,
      }
    end

    def data
      return head :forbidden unless can_view

      query_filters = params.permit(:date_from, :date_to, :page)

      if can_edit && params[:configuration].present?
        return custom_chart_data(query_filters)
      end

      unless params[:chart_id].present?
        return render json: { error: "The chart_id parameter must be specified" }, status: :unprocessable_content
      end

      return render json: @dashboard.chart_data(params[:chart_id], query_filters.to_h)
    rescue ActiveRecord::StatementInvalid => e
      message = can_dangerously_use_sql ? e.message : "Something went wrong fetching the data. Please contact a site admin."
      render json: { error: message }, status: :unprocessable_content
    rescue Skadi::Dashboard::Error => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    def update
      return head :forbidden unless can_view && can_edit

      # The dashboard validator will strongly check the structure of :configuration
      @dashboard.configuration = params.to_unsafe_h[:configuration]

      if @dashboard.save
        head :ok
      else
        render json: { error: "Dashboard validation failed. #{@dashboard.errors.full_messages.join("\n")}" }, status: :unprocessable_content
      end
    end

    private def custom_chart_data(query_filters)
      # The dashboard validator will strongly check the structure of :configuration
      chart_configuration = params[:configuration].to_unsafe_h

      # Temporarily add the chart to the current dashboard so we can validate it, ensuring it's in the right format and that no illegal SQL has been added.
      chart_configuration["id"] = "temporary-chart"
      @dashboard.configuration[0]["children"] << chart_configuration

      unless @dashboard.valid?
        return render json: { error: "Invalid chart configuration:\n#{@dashboard.errors.full_messages.join("\n")}" }, status: :unprocessable_content
      end

      return render json: @dashboard.chart_data("temporary-chart", query_filters.to_h)
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

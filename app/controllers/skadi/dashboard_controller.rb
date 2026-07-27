module Skadi
  class DashboardController < ::ApplicationController
    do_not_track! if defined?(do_not_track!)

    before_action :set_dashboard

    def show
      render :show, locals: {dashboard_config: @dashboard.configuration}
    end

    def data
      query_filters = params.permit(:date_from, :date_to)

      # Todo: select by ID by default, optionally use config if user is admin
      chart_data = @dashboard.chart_data(query_filters.to_h, config_override: JSON.parse(params[:config]))

      render json: chart_data
    rescue Skadi::DashboardQuery::Error, ActiveRecord::StatementInvalid => e
      # Todo: only share the StatementInvalid error message if the user has dangerous sql permission
      render json: {error: e.message}, status: :unprocessable_content
    end

    def update
      # The dashboard validator will strongly check the structure of :configuration
      @dashboard.configuration = params[:configuration].to_unsafe_h

      if @dashboard.save
        head :ok
      else
        render json: {error: "Dashboard validation failed. #{@dashboard.errors.join("\n")}"}, status: :unprocessable_content
      end
    end

    private def set_dashboard
      @dashboard = Skadi::Dashboard.first_or_create!(name: "Default dashboard", configuration: Skadi::Dashboard::DEFAULT_CONFIG)
    end
  end
end

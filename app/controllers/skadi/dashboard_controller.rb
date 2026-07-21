module Skadi
  class DashboardController < ::ApplicationController
    do_not_track! if defined?(do_not_track!)

    def show
      dashboard = Skadi::Dashboard.new

      render :show, locals: { dashboard_config: dashboard.config }
    end

    def data
      query_filters = params.permit(:date_from, :date_to)

      dashboard = Skadi::Dashboard.new

      # Todo: select by ID by default, optionally use config if user is admin
      chart_data = dashboard.chart_data(JSON.parse(params[:config]), query_filters.to_h)

      render json: chart_data
    rescue ActiveRecord::StatementInvalid => e
      # Todo: only share the error message if the user has dangerous sql permission
      render json: {error: e.message}, status: :unprocessable_content
    end
  end
end

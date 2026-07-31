class ApplicationController < ActionController::Base
  include Skadi::Analytics

  cattr_accessor :current_user
  cattr_accessor :skadi_dashboard_view, default: true
  cattr_accessor :skadi_dashboard_edit, default: true
  cattr_accessor :skadi_dashboard_use_sql, default: true
end

Skadi.configure do |config|
  config.user_model = "DummyUser"
  config.user_controller_method = :current_user

  config.dashboard_view_controller_method = :skadi_dashboard_view
  config.dashboard_edit_controller_method = :skadi_dashboard_edit
  config.dashboard_dangerously_use_sql_controller_method = :skadi_dashboard_use_sql

  config.use_anonymity_sets = true
end

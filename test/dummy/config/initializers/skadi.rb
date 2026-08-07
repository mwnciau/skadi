Skadi.configure do |config|
  config.user_model = "DummyUser"
  config.user_controller_method = :current_user

  config.dashboard_view_controller_method = :skadi_dashboard_view
  config.dashboard_edit_controller_method = :skadi_dashboard_edit
  config.dashboard_dangerously_use_sql_controller_method = :skadi_dashboard_use_sql

  config.use_anonymity_sets = true

  config.dashboard_custom_event_fields = {
    stars: {type: :number, filter: true, split: true, sql: "properties->>'starts'"},
  }

  config.dashboard_custom_schema = {
    users: {
      model: "DummyUser",
      fields: {
        username: {
          split: true,
          filter: true,
        },
      },
    },
  }
end

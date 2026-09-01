# This auto-generated file contains the configuration options that you are most
# likely to change. Refer to the Skadi configuration class to see the full list
# of configuration options and their descriptions.
# @see {Skadi::Configuration}

Skadi.configure do |config|
  # Enables anonymity sets without requiring consent. A hash of the user's IP
  # and User Agent is used to track them across the same day. This data is
  # aggregated at the end of the day, anonymising it. Defaults to false.
  #
  # config.use_anonymity_sets = true

  # Enables tracking users without requiring consent. The current user will be
  # attached to site visits and used to de-duplicate visitors.
  #
  # config.track_users = true


  # A string containing the user model class for the application.
  #
  # config.user_model = "User"

  # The method to call within your ApplicationController to get the current user.
  #
  # config.user_controller_method = :current_user


  # Methods to call within your ApplicationController to authenticate users for
  # using the Skadi dashboard. These methods should return a boolean.
  #
  # config.dashboard_view_controller_method = :skadi_dashboard_can_view
  # config.dashboard_edit_controller_method = :skadi_dashboard_can_edit
  # config.dashboard_dangerously_use_sql_controller_method = :skadi_dashboard_can_dangerously_use_sql


  # Add custom fields to the events table in the Skadi dashboard.
  # @see [Skadi::Schema]
  #
  # config.dashboard_custom_event_fields = {
  #   http_verb: {
  #     # How the field is displayed in the dashboard. A label is auto-generated
  #     # if omitted ("http_verb" => "Http Verb").
  #     label: "HTTP Verb",
  #     # Additional information displayed with this field in the dashboard.
  #     description: "Typically, GET requests are page views, and POST, PUT, PATCH and DELETE are form submissions.",
  #     # The datatype, one of: :one_of, :date, :string, :number, :boolean.
  #     # Defaults to :string if omitted.
  #     type: :one_of,
  #     # Options for filtering in the dashboard when the :one_of type is used
  #     options: %w[GET POST PUT PATCH DELETE]
  #     # Whether this field can be selected for tables
  #     select: true,
  #     # Whether users can filter by this field
  #     filter: true,
  #     # Whether this field can be used to split a chart view
  #     split: true,
  #     # The SQL expression used to get this field
  #     sql: "properties->>'http_verb'",
  #   },
  # }

  # Add your own database tables to the Skadi dashboard.
  # @see [Skadi::Schema] for examples
  #
  config.dashboard_custom_schema = {
    form_responses: {
      model: "FormResponse",
      fields: {
        date: {
          type: :date,
          filter: true,
          sql: "form_responses.created_at",
        },
        form_name: {
          split: true,
          filter: true,
        },
        data: {},
      },
    },
  }
end

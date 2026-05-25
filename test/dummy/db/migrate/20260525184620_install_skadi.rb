class InstallSkadi < ActiveRecord::Migration[8.1]
  def change
    create_table :skadi_visits do |t|
      # A random uuid identifying the visit. This will be sent to the front-end to allow updates to the visit javascript flag without exposing details about the site analytics to the user.
      t.string :visit_token, limit: 36, null: false

      # A token identifying the user. This will either be a token generated from an anonymisation set based on the user's IP and User Agent, or it will be sourced from a cookie.
      t.string :tracking_token, limit: 36

      # The ID of a logged in user. The FK is intentionally absent in case the host app doesn't have a users table.
      t.references :user, type: :bigint, index: false

      t.text :referrer
      t.text :landing_page

      # Standard UTM parameters
      t.text :utm_source
      t.text :utm_medium
      t.text :utm_term
      t.text :utm_content
      t.text :utm_campaign

      # Flag to store whether JavaScript is enabled. This is updated when the first request is sent from the front-end.
      t.boolean :javascript_enabled, null: false, default: false

      t.timestamps
    end

    add_index :skadi_visits, :visit_token, unique: true
    add_index :skadi_visits, :created_at
    add_index :skadi_visits, [:tracking_token, :created_at]
    add_index :skadi_visits, [:user_id, :created_at]

    create_table :skadi_views do |t|
      # Intentionally left nullable as not all requests will have a visit in the case a user has requested no tracking.
      t.references :visit, foreign_key: { to_table: :skadi_visits, on_delete: :cascade }, index: false

      # A random uuid identifying the view. This will be sent to the front-end to allow updates to the view metrics without exposing details about the site analytics to the user.
      t.string :view_token, limit: 36, null: false

      t.string :controller, null: false
      t.string :action, null: false
      t.string :verb, null: false
      t.text :path, null: false
      t.json :query_params

      # Referrer URL, as reported by the user's browser
      t.text :referrer

      # The page the user clicked on when leaving the page
      t.text :exit_page

      # Metrics calculated in the front end that update after the view event is created
      t.integer :active_time_seconds
      t.integer :max_scroll_percent

      # Todo: figure out which performance metrics we want from js`performance.getEntriesByType("navigation")`

      # I.e. server response time
      # navEntry.responseStart - navEntry.startTime
      t.integer :time_to_first_byte

      # I.e. how big the response is
      # navEntry.responseEnd - navEntry.responseStart
      t.integer :time_to_download

      # Some sort of intermediary?? Maybe not useful
      # navEntry.domContentLoadedEventEnd - navEntry.responseEnd
      t.integer :time_to_load_dom

      # I.e. how long the browser took to render the page
      # navEntry.loadEventEnd - navEntry.responseEnd
      t.integer :total_time_to_load

      # FP/FCP?? https://developer.mozilla.org/en-US/docs/Web/API/PerformancePaintTiming

      t.integer :load_time

      t.timestamps
    end

    add_index :skadi_views, :view_token, unique: true
    add_index :skadi_views, [:path, :created_at]
    add_index :skadi_views, [:visit_id, :created_at]

    create_table :skadi_events do |t|
      # Intentionally left nullable as not all requests will have a visit in the case a user has requested no tracking.
      t.references :visit, foreign_key: { to_table: :skadi_visits, on_delete: :cascade }, index: false

      # Intentionally left nullable as not all requests will have a visit in the case a user has requested no tracking.
      t.references :view, foreign_key: { to_table: :skadi_views, on_delete: :cascade }, index: false

      t.string :name, null: false
      t.json :properties

      t.datetime :created_at, null: false
    end

    add_index :skadi_events, [:name, :created_at]
    add_index :skadi_events, [:view_id, :created_at]
    add_index :skadi_events, [:visit_id, :created_at]

    # Store demographic data separately so that it cannot be used to identify users
    # E.g. screen size, language, timezone, pointer type (mouse, touch), can-hover, prefers reduced motion, prefers contrast, forced colours, prefers dark mode
    create_table :skadi_demographics do |t|
      t.string :metric_name, null: false
      t.string :metric_value, null: false
      t.date :recorded_on, null: false
      t.integer :count, null: false, default: 0
    end

    add_index :skadi_demographics, [:metric_name, :metric_value, :recorded_on], unique: true
  end
end

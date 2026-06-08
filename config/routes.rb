Skadi::Engine.routes.draw do
  root to: "dashboard#show"

  post "/", to: "tracking#track", as: :tracking_endpoint

  get "/skadi.js", to: "asset#tracking_script", as: :tracking_script
  get "/dashboard.css", to: "asset#dashboard_css", as: :dashboard_css
  get "/dashboard.js", to: "asset#dashboard_js", as: :dashboard_js
end

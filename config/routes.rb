Skadi::Engine.routes.draw do
  post "/", to: "tracking#track", as: :tracking_endpoint

  get "/skadi.js", to: "asset#tracking_script", as: :tracking_script
end

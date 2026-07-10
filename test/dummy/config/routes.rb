Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  mount Skadi::Engine => "/skadi"

  # Defines the root path route ("/")
  root "tracked#tracked_action"

  match "track", to: "tracked#tracked_action", as: :tracked_action, via: :all

  get "untracked_action", to: "tracked#untracked_action", as: :untracked_action
  get "untracked_controller", to: "untracked#untracked_controller", as: :untracked_controller
  get "untracked_controller_with_kwargs", to: "tracked#untracked_controller_with_kwargs", as: :untracked_controller_with_kwargs
  get "queue_then_untrack", to: "tracked#queue_then_untrack", as: :queue_then_untrack

  post "anonymity_sets_on", to: "consent#anonymity_sets_on", as: :anonymity_sets_on
  post "anonymity_sets_off", to: "consent#anonymity_sets_off", as: :anonymity_sets_off
  post "cookies_on", to: "consent#cookies_on", as: :cookies_on
  post "cookies_off", to: "consent#cookies_off", as: :cookies_off
  post "track_users_on", to: "consent#track_users_on", as: :track_users_on
  post "track_users_off", to: "consent#track_users_off", as: :track_users_off

  scope :events do
    get "simple", to: "events#simple", as: :simple_event
    get "multiple", to: "events#multiple", as: :multiple_events
  end

  scope :demographics do
    get "simple", to: "demographics#simple", as: :simple_demographic
    get "multiple", to: "demographics#multiple", as: :multiple_demographics
  end

  get "test", to: "tracked#test_action", as: :test
end

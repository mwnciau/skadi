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

  scope :events do
    get "simple", to: "events#simple", as: :simple_event
    get "with_properties", to: "events#with_properties", as: :with_properties_event
    get "sensitive", to: "events#sensitive", as: :sensitive_event
    get "multiple", to: "events#multiple", as: :multiple_events
    get "mixed_sensitivity", to: "events#mixed_sensitivity", as: :mixed_sensitivity_events
  end

  scope :demographics do
    get "simple", to: "demographics#simple", as: :simple_demographic
    get "multiple", to: "demographics#multiple", as: :multiple_demographics
    get "view", to: "demographics#view", as: :view_demographic
    get "mixed_specificity", to: "demographics#mixed_specificity", as: :mixed_specificity_demographics
  end

  get "test", to: "tracked#test_action", as: :test
end

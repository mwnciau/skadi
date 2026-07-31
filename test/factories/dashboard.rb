FactoryBot.define do
  factory :dashboard, class: ::Skadi::Dashboard do
    name { "Dashboard" }
    description { "" }
    configuration { Skadi::Dashboard.default_configuration }

    can_dangerously_use_sql { true }
  end
end

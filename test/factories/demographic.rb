FactoryBot.define do
  factory :demographic, class: ::Skadi::Demographic do
    uri { "" }
    name { "my demographic" }
    value { "value" }
    recorded_on { Date.today }
  end
end

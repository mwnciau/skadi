FactoryBot.define do
  factory :demographic, class: ::Skadi::Demographic do
    uri { "" }
    recorded_on { Date.today }
  end
end

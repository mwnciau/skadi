FactoryBot.define do
  factory :view, class: Skadi::View do
    view_token { SecureRandom.uuid_v7 }

    controller { "application" }
    action { "show" }
    verb { "GET" }
    path { "/" }
    query_params { {} }

    referrer { "https://example.com/referrer" }
    exit_page { nil }

    verified { false }
  end
end

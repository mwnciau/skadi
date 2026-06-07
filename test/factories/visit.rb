FactoryBot.define do
  factory :visit, class: Skadi::Visit do
    visit_token { SecureRandom.uuid_v7 }
    tracking_token { nil }

    user_id { nil }

    landing_page { "/" }
    referrer { "https://example.com/referrer" }

    utm_source { nil }
    utm_medium { nil }
    utm_term { nil }
    utm_content { nil }
    utm_campaign { nil }

    verified { false }
  end
end

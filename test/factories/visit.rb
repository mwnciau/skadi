FactoryBot.define do
  factory :visit do
    visit_token { SecureRandom.uuid_v7 }
    tracking_token { null }

    user_id { nil }

    landing_page { "/" }
    referrer { "https://example.com/referrer" }

    utm_source { nil }
    utm_medium { nil }
    utm_term { nil }
    utm_content { nil }
    utm_campaign { nil }

    javascript_enabled { false }
  end
end

FactoryBot.define do
  factory :user, class: DummyUser do
    username { "bob" }
  end
end

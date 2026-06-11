require_relative "test_case"

module Skadi::Models
  class VisitTest < TestCase
    TRACKING_TOKEN = "8cec5a7a-7bf7-403f-b15e-b2e45944182c"

    test "find active visit for tracking token" do
      visit = create :visit, tracking_token: TRACKING_TOKEN

      result = Skadi::Visit.find_active_visit_for(TRACKING_TOKEN, nil)

      assert_equal visit, result
    end

    test "does not find inactive visit" do
      create :visit, tracking_token: TRACKING_TOKEN, created_at: 121.minutes.ago

      result = Skadi::Visit.find_active_visit_for(TRACKING_TOKEN, nil)

      assert_nil result
    end

    test "find active visit for user" do
      user = create :user
      visit = create :visit, user: user

      result = Skadi::Visit.find_active_visit_for(nil, user)

      assert_equal visit, result
    end

    test "does not find unrelated visits for null users" do
      create :visit, tracking_token: TRACKING_TOKEN, user: nil

      result = Skadi::Visit.find_active_visit_for(nil, nil)

      assert_nil result
    end

    test "does not find unrelated visits for null tracking tokens" do
      create :visit, tracking_token: nil

      result = Skadi::Visit.find_active_visit_for(nil, nil)

      assert_nil result
    end

    test "does not find unrelated visits for unpersisted users" do
      user = DummyUser.new(username: "bob")
      create :visit, tracking_token: TRACKING_TOKEN, user: nil

      result = Skadi::Visit.find_active_visit_for(nil, user)

      assert_nil result
    end

    test "does not return visit when user does not match" do
      user = create :user
      other_user = create :user
      create :visit, tracking_token: TRACKING_TOKEN, user: other_user

      result = Skadi::Visit.find_active_visit_for(TRACKING_TOKEN, user)

      assert_nil result
    end
  end
end

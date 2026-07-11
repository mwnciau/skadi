require_relative "../test_case"

module Skadi::Unit
  module ControllerDelegate
    module Consent
      class UserTest < TestCase
        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
        #           Consent tests          #
        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

        test "consent sets cookie" do
          skadi.user_consent!(true)

          assert_cookie "skadi_track_user", "1"
        end

        test "cookie grants consent" do
          @request.cookies["skadi_track_user"] = "1"

          assert skadi.user_consent?
        end

        test "consent sets user_id" do
          visit = build :visit, tracking_token: nil
          skadi._attach(visit: visit)

          user = create :user
          skadi.instance_variable_set(:@logged_in_user, user)

          skadi.user_consent!(true)

          assert_equal user.id, visit.user_id
        end

        test "consent builds visit if one doesn't exist" do
          view = build :view, visit: nil
          skadi._attach(view: view)

          user = create :user
          skadi.instance_variable_set(:@logged_in_user, user)

          skadi.user_consent!(true)

          refute_nil view.visit
          assert_equal user.id, view.visit.user_id
        end

        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
        #           Opt out tests          #
        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

        test "opt out sets cookie" do
          @request.cookies["skadi_track_user"] = "1"

          skadi.user_consent!(false)

          assert_cookie "skadi_track_user", "0"
        end

        test "opt out removes user from visit" do
          visit = build :visit, user_id: create(:user)
          skadi._attach(visit: visit)

          skadi.user_consent!(false)

          assert_nil visit.user_id
        end

        test "opt out removes user from previous visits" do
          user = create(:user)

          visit = build :visit, user_id: user.id
          skadi._attach(visit: visit)

          old_visit = create :visit, user_id: user.id

          skadi.user_consent!(false)

          assert_nil old_visit.reload.user_id
        end

        test "opt out with no visit" do
          user = create :user
          skadi.instance_variable_set(:@logged_in_user, user)

          @request.cookies["skadi_track_user"] = "1"

          skadi.user_consent!(false)

          assert_cookie "skadi_track_user", "0"
        end

        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
        #        Configuration tests       #
        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

        test "track_users on by default" do
          Skadi.configuration.track_users = true

          user = create :user
          skadi.instance_variable_set(:@logged_in_user, user)

          skadi.send(:build_visit)

          assert_equal user, skadi.visit.user
          assert skadi.user_consent?
        end

        test "track_users off by default" do
          Skadi.configuration.track_users = false
          @request.env["HTTP_REFERER"] = "force a visit to be created"

          user = create :user
          skadi.instance_variable_set(:@logged_in_user, user)

          skadi.send(:build_visit)

          assert_nil skadi.visit.user
          refute skadi.user_consent?
        end
      end
    end
  end
end

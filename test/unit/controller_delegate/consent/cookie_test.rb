require_relative "../test_case"

module Skadi::Unit
  module ControllerDelegate
    module Consent
      class CookieTest < TestCase
        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
        #           Consent tests          #
        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

        test "consent sets cookie" do
          skadi.cookie_consent!(true)

          assert_cookie "skadi_id", Skadi::CookieManager::UUID_REGEX
        end

        test "cookie grants consent" do
          @request.cookies["skadi_id"] = TRACKING_TOKEN

          assert skadi.cookie_consent?
        end

        test "consent sets cookies_enabled" do
          visit = build :visit, tracking_token: nil
          skadi._attach(visit: visit)

          skadi.cookie_consent!(true)

          assert visit.cookies_enabled
        end

        test "consent adds tracking token" do
          visit = build :visit, tracking_token: nil
          skadi._attach(visit: visit)

          skadi.cookie_consent!(true)

          assert_match Skadi::CookieManager::UUID_REGEX, visit.tracking_token
        end

        test "consent does not overwrite existing cookie" do
          @request.cookies["skadi_id"] = TRACKING_TOKEN

          skadi.cookie_consent!(true)

          assert_cookie "skadi_id", TRACKING_TOKEN
        end

        test "consent uses existing visit cookie token" do
          visit = build :visit, tracking_token: TRACKING_TOKEN, cookies_enabled: true
          skadi._attach(visit: visit)

          skadi.cookie_consent!(true)

          assert_match TRACKING_TOKEN, visit.tracking_token
          assert_cookie "skadi_id", TRACKING_TOKEN
        end

        test "consent builds visit if one doesn't exist" do
          view = build :view, visit: nil
          skadi._attach(view: view)

          skadi.cookie_consent!(true)

          refute_nil view.visit
          assert_match Skadi::CookieManager::UUID_REGEX, view.visit.tracking_token
          assert_cookie "skadi_id", view.visit.tracking_token
          assert view.visit.cookies_enabled
        end

        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
        #           Opt out tests          #
        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

        test "opt out sets cookie" do
          @request.cookies["skadi_id"] = TRACKING_TOKEN

          skadi.cookie_consent!(false)

          assert_cookie "skadi_id", nil
        end

        test "opt out sets cookies_enabled to false" do
          visit = build :visit, tracking_token: TRACKING_TOKEN, cookies_enabled: true
          skadi._attach(visit: visit)

          skadi.cookie_consent!(false)

          refute visit.cookies_enabled
        end

        test "opt out leaves visit token on matching visits" do
          visit = build :visit, tracking_token: TRACKING_TOKEN
          skadi._attach(visit: visit)

          # An older visit with the same token
          old_visit = create :visit, tracking_token: TRACKING_TOKEN

          skadi.cookie_consent!(false)

          assert_equal TRACKING_TOKEN, visit.tracking_token
          assert_equal TRACKING_TOKEN, old_visit.reload.tracking_token
        end

        test "opt out falls back to anonymity set if enabled" do
          visit = build :visit, tracking_token: TRACKING_TOKEN
          skadi._attach(visit: visit)

          @request.cookies["skadi_anonymity_set"] = "1"

          skadi.cookie_consent!(false)

          assert_equal anonymity_set, visit.tracking_token
        end
      end
    end
  end
end

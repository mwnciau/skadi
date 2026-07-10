require_relative "../test_case"

module Skadi::Unit
  module ControllerDelegate
    module Consent
      class AnonymitySetTest < TestCase
        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
        #           Consent tests          #
        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

        test "consent sets cookie" do
          # Attach a visit to prevent an error when it tries to build one
          skadi._attach(visit: build(:visit))

          skadi.anonymity_set_consent!(true)

          assert_cookie "skadi_anonymity_set", "1"
        end

        test "consent adds anonymity set token" do
          visit = build :visit, tracking_token: nil
          skadi._attach(visit: visit)

          skadi.anonymity_set_consent!(true)

          assert_match Skadi::CookieManager::UUID_REGEX, visit.tracking_token
        end

        test "consent does not overwrite existing token" do
          visit = build :visit, tracking_token: TRACKING_TOKEN
          skadi._attach(visit: visit)

          skadi.anonymity_set_consent!(true)

          assert_match TRACKING_TOKEN, visit.tracking_token
        end

        test "consent builds visit if one doesn't exist" do
          view = build :view, visit: nil
          skadi._attach(view: view)

          skadi.anonymity_set_consent!(true)

          refute_nil view.visit
          assert_match Skadi::CookieManager::UUID_REGEX, view.visit.tracking_token
        end

        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #
        #           Opt out tests          #
        # -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= #

        test "opt out sets cookie" do
          skadi.anonymity_set_consent!(false)

          assert_cookie "skadi_anonymity_set", "0"
        end

        test "opt out clears anonymity set token" do
          visit = build :visit, tracking_token: anonymity_set
          skadi._attach(visit: visit)

          skadi.anonymity_set_consent!(false)

          assert_nil visit.tracking_token
        end

        test "opt out clears anonymity set token from existing visits" do
          visit = create :visit, tracking_token: anonymity_set
          skadi._attach(visit: visit)

          old_visit = create :visit, tracking_token: anonymity_set

          skadi.anonymity_set_consent!(false)

          assert_nil visit.tracking_token
          assert_nil old_visit.reload.tracking_token
        end
      end
    end
  end
end

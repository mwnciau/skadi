class ConsentController < ApplicationController
  def anonymity_sets_on
    skadi.anonymity_set_consent!(true)

    head :no_content
  end

  def anonymity_sets_off
    skadi.anonymity_set_consent!(false)

    head :no_content
  end

  def cookies_on
    skadi.cookie_consent!(true)

    head :no_content
  end

  def cookies_off
    skadi.cookie_consent!(false)

    head :no_content
  end

  def track_users_on
    skadi.user_consent!(true)

    head :no_content
  end

  def track_users_off
    skadi.user_consent!(false)

    head :no_content
  end
end

require "test_helper"

class ControllerTest < ActionDispatch::IntegrationTest
  def test_calculates_tracking_token_during_request
    Skadi.configuration.use_anonymisation_sets = true

    get example_index_path

    assert_response :success
  end

  def test_tracking_token_is_nil_when_anonymisation_sets_are_disabled
    Skadi.configuration.use_anonymisation_sets = false

    get example_index_path

    assert_response :success
  end
end
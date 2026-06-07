require "integration/test_case"

module Skadi::Integration
  module TrackingController
    class DemographicsTest < TestCase
      setup do
        view = create :view

        @view_token = view.view_token
      end

      test "tracks demographics" do
        post skadi.tracking_endpoint_path, params: { view: @view_token, demographics: [
          {uri: "/pages/:id", name: "first-contentful-paint", value: "< 1000ms"},
          {name: "browser", value: "Chrome"},
        ] }, as: :json

        assert_response :no_content
        assert_equal 2, Skadi::Demographic.count

        demographics = Skadi::Demographic.all

        assert_equal "first-contentful-paint", demographics.first.name
        assert_equal "< 1000ms", demographics.first.value
        assert_equal "/pages/:id", demographics.first.uri
        assert_equal 1, demographics.first.count

        assert_equal "browser", demographics.last.name
        assert_equal "Chrome", demographics.last.value
        assert_equal "", demographics.last.uri
        assert_equal 1, demographics.last.count
      end

      test "increments existing demographics" do
        view = create :view
        create :demographic, recorded_on: Date.today, uri: "/pages/:id", name: "first-contentful-paint", value: "< 1000ms", count: 6
        create :demographic, recorded_on: Date.today, name: "browser", value: "Chrome", count: 2

        post skadi.tracking_endpoint_path, params: { view: @view_token, demographics: [
          {uri: "/pages/:id", name: "first-contentful-paint", value: "< 1000ms"},
          {name: "browser", value: "Chrome"},
        ] }, as: :json

        assert_response :no_content
        assert_equal 2, Skadi::Demographic.count

        demographics = Skadi::Demographic.all

        assert_equal "first-contentful-paint", demographics.first.name
        assert_equal 7, demographics.first.count

        assert_equal "browser", demographics.last.name
        assert_equal 3, demographics.last.count
      end

      test "ignores invalid demographics" do
        post skadi.tracking_endpoint_path, params: { view: @view_token, demographics: [
          {name: "valid demographic", value: "value"},
          {name: "", value: "value"},
          {name: 123, value: "value"},
          {value: "value"},
          {name: "name", value: ""},
          {name: "name", value: 123},
          {name: "name"},
          {name: "name", value: "value", uri: 123},
          {name: "name", value: "value", uri: ""},
        ] }, as: :json

        assert_response :no_content
        assert_equal 1, Skadi::Demographic.count
        assert_equal "valid demographic", Skadi::Demographic.first.name
      end

      test "non-array passed to demographics" do
        post skadi.tracking_endpoint_path, params: { view: @view_token, demographics: "my demographics"}, as: :json

        assert_response :no_content
        assert_equal 0, Skadi::Demographic.count
      end
    end
  end
end

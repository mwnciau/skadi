require "integration/test_case"

module Skadi::Integration
  class DummyView
    include Skadi::ApplicationHelper
    include ::ActionView::Helpers::TagHelper

    attr_accessor :request, :skadi_view, :skadi_visit, :content_security_policy_nonce

    def skadi
      Skadi::Engine.routes.url_helpers
    end
  end

  class ApplicationHelperTest < TestCase
    def setup
      @dummy = DummyView.new

      @dummy.request = ActionDispatch::Request.new("HTTP_HOST" => "example.com")
      @dummy.skadi_visit = @visit = create :visit
      @dummy.skadi_view = @view = create :view, visit: @dummy.skadi_visit
      @dummy.content_security_policy_nonce = "12345-this-is-a-nonce"
    end

    private def skadi_tag(*args, **kwargs)
      @dummy.skadi_tag(*args, **kwargs)
    end

    private def generic_tests(tag_src)
      tag = Nokogiri::HTML.fragment(tag_src).children.first
      tag_name = tag.name
      tag_attributes = tag.attributes.transform_values(&:value)

      assert_equal "script", tag_name
      assert_equal "/skadi/", tag_attributes["data-endpoint"]
      assert_equal @view.view_token, tag_attributes["data-view"]
      assert_equal "12345-this-is-a-nonce", tag_attributes["nonce"]

      tag
    end

    test "default renders inline" do
      tag = generic_tests skadi_tag

      # The script content should be about 1-2KB
      assert tag.inner_html.length > 1_024
      assert tag.inner_html.length < 2_048
    end

    test "inline rendering of tag" do
      tag = generic_tests skadi_tag(:inline)

      assert_match "navigator.sendBeacon", tag.inner_html

      # The script content should be about 1-2KB
      assert tag.inner_html.length > 1_024
      assert tag.inner_html.length < 2_048
    end

    test "route rendering of tag" do
      tag = generic_tests skadi_tag(:route)

      assert_equal 0, tag.inner_html.length
      assert_equal "/skadi/skadi.js?v=#{Skadi::VERSION}", tag.attributes["src"].value
    end

    test "invalid type" do
      assert_raises Skadi::ApplicationHelper::Error do
        skadi_tag(:invalid)
      end
    end
  end
end

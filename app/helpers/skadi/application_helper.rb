module Skadi
  module ApplicationHelper
    class InvalidSkadiTagType < StandardError; end

    mattr_accessor :skadi_script_src

    def skadi_tag(type = :inline)
      return if skadi.do_not_track? || skadi.view.nil?

      tag_attributes = {
        data: {
          uri: request.route_uri_pattern,
          endpoint: Skadi::Engine.routes.url_helpers.tracking_endpoint_path,
          view: skadi.view.token,
        },
        nonce: content_security_policy_nonce,
      }
      tag_attributes[:data][:visit] = "1" if skadi.new_visit?

      case type
        when :route
        content_tag("script", "", {
          src: Skadi::Engine.routes.url_helpers.tracking_script_path(v: Skadi::VERSION),
          **tag_attributes,
        })
        when :inline
        self.skadi_script_src ||= Engine.root.join("app", "assets", "builds", "skadi.js").read.html_safe
        content_tag(
          "script",
          skadi_script_src,
          tag_attributes,
        )
        else
        raise InvalidSkadiTagType.new("Invalid type given to skadi_tag. Expecting :route, :inline, but got :#{type}.")
      end
    end
  end
end

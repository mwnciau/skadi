module Skadi
  module ApplicationHelper
    class InvalidSkadiTagType < StandardError; end

    mattr_accessor :skadi_script_src

    def skadi_tag(type = :route)
      tag_attributes = {
        data: {
          uri: request.route_uri_pattern,
          endpoint: skadi.tracking_endpoint_path,
          view: skadi_view.view_token,
        },
        nonce: content_security_policy_nonce,
      }
      tag_attributes[:data][:visit] = "1" if skadi_visit&.new_record?

      case type
      when :route
        content_tag("script", "", {
          src: skadi.tracking_script_path(v: Skadi::VERSION),
          **tag_attributes,
        })
      when :inline
        self.skadi_script_src ||= Engine.root.join("app", "assets", "builds", "skadi.js").read.html_safe
        content_tag(
          "script",
          self.skadi_script_src,
          tag_attributes,
        )
      else
        raise InvalidSkadiTagType.new("Invalid type given to skadi_tag. Expecting :route, :inline, but got :#{type}.")
      end
    end
  end
end

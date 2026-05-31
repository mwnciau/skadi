module Skadi
  module ApplicationHelper
    class InvalidSkadiTagType < StandardError; end

    def skadi_tag(type = :route)
      case type
        when :route
          content_tag("script", "", {
            src: skadi.tracking_script_path(v: Skadi::VERSION),
            data: {
              pageUri: request.route_uri_pattern,
              endpoint: skadi.tracking_endpoint_path,
              csrf: form_authenticity_token,
            },
            nonce: content_security_policy_nonce,
          })
        else
          raise InvalidSkadiTagType.new("Invalid type given to skadi_tag. Expecting :route, but got :#{type}.")
      end
    end
  end
end
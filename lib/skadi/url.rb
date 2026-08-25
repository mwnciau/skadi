module Skadi
  # Helper functions for generating and redacting URLs
  module Url
    # Formats the path for Skadi views. Note that the path here uses PATH_INFO, which does not include the query string or fragment.
    # @param request [ActionDispatch::Request]
    # @return [String]
    def self.view_path_from_request(request)
      path = +""

      if Skadi.configuration.store_domain_in_views
        path << request.host_with_port
      end

      # Normalise the path by removing any trailing slashes
      path << ((request.path == "/" || request.path == "") ? "/" : request.path.chomp("/"))

      path
    end

    # @param query_params [Hash, ActiveSupport::HashWithIndifferentAccess]
    # @return [Hash]
    def self.whitelist_query_params(query_params)
      # Normalise the input to a Hash with symbolic keys
      query_params = query_params.to_h.symbolize_keys

      return query_params unless Skadi.configuration.use_query_param_whitelist

      whitelist = Skadi.configuration.query_param_whitelist
      return {} if whitelist.empty?

      query_params.slice(*whitelist)
    end

    # Strips non-whitelisted query params and normalises URLs
    # @param url [String]
    # @param request [ActionDispatch::Request, nil] the current request - used to truncate the current host from URLs
    # @return [String, nil]
    def self.redact_and_normalise_url(url, request: nil)
      return nil unless url.is_a?(String) && url.present?

      uri = URI.parse(url[0, Skadi.configuration.max_url_length])
      return nil if uri.opaque

      query_params = Rack::Utils.parse_nested_query(uri.query) if uri.query.present?
      param_string = whitelist_query_params(query_params).to_query if query_params.present?

      result = +""

      interesting_scheme = uri.scheme.present? && ![ "http", "https" ].include?(uri.scheme)
      # Only record interesting schemes, e.g. "android-app://"
      result += "#{uri.scheme}://" if interesting_scheme

      host_with_port = +""
      if uri.host.present?
        host_with_port << uri.host
        # Only include port if it's non-standard
        host_with_port << ":#{uri.port}" if uri.port != uri.default_port
      end

      is_local = request.present? && host_with_port == request.host_with_port
      result << host_with_port if interesting_scheme || Skadi.configuration.store_domain_in_views || !is_local

      path = uri.path&.start_with?("/") ? uri.path : "/#{uri.path}"
      # Normalise the trailing slash
      result << (path == "/" ? "/" : path.delete_suffix("/"))

      result << (param_string.present? ? "?#{param_string}" : "")

      return result
    rescue URI::InvalidURIError, Rack::QueryParser::ParameterTypeError, Rack::QueryParser::QueryLimitError
      return nil
    end
  end
end

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
    # @return [String, nil]
    def self.redact_and_normalise_url(url)
      return nil unless url.present?

      uri = URI.parse(url)
      return nil if uri.opaque

      query_params = Rack::Utils.parse_nested_query(uri.query) if uri.query.present?
      param_string = whitelist_query_params(query_params).to_query if query_params.present?

      result = +""

      # Only record interesting schemes, e.g. "android-app://"
      result += "#{uri.scheme}://" if uri.scheme.present? && !["http", "https"].include?(uri.scheme)

      result += uri.host if uri.host.present?

      # Only include port if it's non-standard
      result << ":#{uri.port}" if uri.port != uri.default_port

      # Normalise the trailing slash
      result << ((uri.path == "" || uri.path == "/") ? "/" : uri.path.chomp("/")) unless uri.path.nil?

      result << (param_string.present? ? "?#{param_string}" : "")

      result
    rescue URI::InvalidURIError
      nil
    end
  end
end

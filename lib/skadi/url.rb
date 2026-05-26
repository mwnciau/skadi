module Skadi
  # Helper functions for generating and redacting URLs
  class Url
    # @param request [ActionDispatch::Request]
    # @param query_param_whitelist [Array<Symbol>]
    def self.view_path_from_request(request)
      path = +""

      if Skadi.configuration.store_domain_in_views
        path << "#{request.host_with_port}/"
      end

      path << "#{request.path}"

      path
    end

    # @param query_params [ActiveSupport::HashWithIndifferentAccess]=
    # @return [Hash]
    def self.whitelist_query_params(query_params)
      return query_params unless Skadi.configuration.use_query_param_whitelist
      whitelist = Skadi.configuration.query_param_whitelist
      return {} if whitelist.empty?

      whitelisted_params = {}

      whitelist.each do |whitelisted_key|
        if query_params.has_key?(whitelisted_key)
          whitelisted_params[whitelisted_key] = query_params[whitelisted_key]
        end
      end

      whitelisted_params
    end

    # @param url [String]
    # @return [String|nil]
    def self.whitelist_query_params_for_url(url)
      return nil unless url.present?

      uri = URI.parse(url)
      query_params = HashWithIndifferentAccess.new(Rack::Utils.parse_nested_query(uri.query))

      param_string = whitelist_query_params(query_params).to_query

      "#{uri.scheme}://#{uri.host}#{uri.path}#{param_string.present? ? "?#{param_string}" : ""}"
    rescue URI::InvalidURIError
      nil
    end
  end
end
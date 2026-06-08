module Skadi
  # Controller to serve assets directly so Skadi assets can be loaded regardless of asset pipeline
  class AssetController < ActionController::Metal
    include ActionController::ConditionalGet
    include ActionController::DataStreaming

    def tracking_script
      serve_built_asset("tracking.js")
    end

    def dashboard_js
      serve_built_asset("dashboard.js")
    end

    def dashboard_css
      serve_built_asset("dashboard.css", type: "text/css")
    end

    private def serve_built_asset(file_name, type: "application/javascript")
      file_path = Engine.root.join("app", "assets", "builds", file_name)

      # Set a long expiry time - the include helper will append the app version number ensuring any changes will be loaded
      expires_in 1.year, public: true, must_revalidate: false

      send_file file_path, disposition: nil, type: type
    end
  end
end

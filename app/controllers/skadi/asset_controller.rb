module Skadi
  # Controller to serve assets directly so Skadi assets can be loaded regardless of asset pipeline
  class AssetController < ApplicationController
    # The assets served by this controller do not contain any sensitive information, so it is safe to skip forgery protection, allowing them to be loaded, e.g. via a <script> tag.
    skip_forgery_protection

    def tracking_script
      file_path = Engine.root.join("app", "assets", "builds", "skadi.js")

      # Set a long expiry time - the include helper will append the app version number ensuring any changes will be loaded
      expires_in 1.year, public: true, must_revalidate: false
      verify_same_origin_request
      send_file file_path, disposition: nil
    end
  end
end

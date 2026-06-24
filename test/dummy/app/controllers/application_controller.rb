class ApplicationController < ActionController::Base
  include Skadi::Analytics

  cattr_accessor :current_user
end

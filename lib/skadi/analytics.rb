# Adds Skadi Analytics helper methods to your controller, and enabled automatic tracking if configured.
module Skadi
  module Analytics
    extend ActiveSupport::Concern

    included do
      around_action :skadi_track

      # Make skadi available in the view for when we output the frontend script
      helper_method :skadi

      # Add the Skadi view helper methods
      helper Skadi::ApplicationHelper

      # Disable Skadi tracking for the current controller
      def self.do_not_track!(**kwargs)
        skip_around_action :skadi_track, **kwargs
      end
    end

    def skadi
      @_skadi ||= Skadi::ControllerDelegate.new(self)
    end

    def skadi_track
      skadi._prepare

      yield

      skadi._persist
    end

    delegate :do_not_track!, to: :skadi
  end
end

module Skadi
  class Engine < ::Rails::Engine
    isolate_namespace Skadi

    config.after_initialize do
      # Validate the configuration and output any errors to the Rails log
      Skadi.configuration.validate!

      if Skadi.configuration.db_connects_to
        Skadi::ApplicationRecord.connects_to(**Skadi.configuration.db_connects_to)
      end

      if Skadi.configuration.user_model
        Skadi::Visit.belongs_to :user, class_name: Skadi.configuration.user_model.to_s, optional: true
      end
    end
  end
end

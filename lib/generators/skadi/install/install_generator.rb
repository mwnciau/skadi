require "rails/generators"
require "rails/generators/active_record"

module Skadi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class Error < StandardError; end

      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      desc "Generates the Skadi analytics migration"

      VALID_DB_ENGINES = [ :postgres, :mysql, :sqlite ]
      class_option :db_engine,
        type: :string,
        desc: "Database engine (postgres, mysql, sqlite). Auto-detected from the app's database config when omitted."

      VALID_USER_ID_TYPES = [ :bigint, :integer, :uuid, :string ]
      class_option :user_id_type,
        type: :string,
        default: "bigint",
        desc: "Column type of your users table primary key (bigint, integer, uuid, string)"

      def self.next_migration_number(dirname) = ::ActiveRecord::Generators::Base.next_migration_number(dirname)

      def create_migration_file
        raise Error.new("Invalid database engine specified") unless VALID_DB_ENGINES.include?(db_engine)
        raise Error.new("Invalid user id type specified") unless VALID_USER_ID_TYPES.include?(user_id_type)

        migration_template "skadi_migration.rb.erb",
          "db/migrate/install_skadi.rb"
      end

      def create_initializer
        template "skadi_initializer.rb", "config/initializers/skadi.rb"
      end

      # Thor requires us to use a private block rather than private on individual definitions
      private

      def user_id_type = options[:user_id_type].to_sym
      def db_engine = (options[:db_engine] || detect_db_engine || :sqlite).to_sym
      def uuid_column_type = (db_engine == :postgres) ? :uuid : :string
      def uuid_column_options = (db_engine == :postgres) ? "" : ", limit: 36"
      def json_column_type
        @_json_column_type ||= case db_engine
          when :mysql
            :json
          when :postgres
            :jsonb
          when :sqlite
            if defined?(ActiveRecord::Base) && ActiveRecord::Base.connection.database_version >= "3.45.0"
              :jsonb
            else
              :json
            end
        end
      rescue StandardError
        # ActiveRecord::Base.connection can throw if the database cannot be reached, in which case we fallback to :json
        return @_json_column_type ||= :json
      end

      def detect_db_engine
        return unless defined? ActiveRecord::Base

        case ActiveRecord::Base.connection_db_config.adapter
          when "postgresql"
            :postgres
          when "mysql2", "trilogy"
            :mysql
          when "sqlite3"
            :sqlite
        end
      rescue StandardError
        nil
      end
    end
  end
end

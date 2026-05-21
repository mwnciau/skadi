require "rails/generators"
require "rails/generators/active_record"

module Skadi
  module Generators
    class InstallGenerator < Rails::Generators::Base
      class Error < StandardError; end

      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      desc "Generates the Skadi analytics migration"

      VALID_DB_ENGINES = [:postgres, :mysql, :sqlite]
      class_option :db_engine,
        type: :string,
        default: "postgres",
        desc: "Database engine (postgres, mysql, sqlite)"

      VALID_USER_ID_TYPES = [:bigint, :integer, :uuid, :string]
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

      private

      def user_id_type = options[:user_id_type].to_sym
      def db_engine = options[:db_engine].to_sym
      def uuid_column_type = db_engine == :postgres ? :uuid : :string
      def uuid_column_options = db_engine == :postgres ? "" : ", limit: 36"
      def json_column_type = db_engine == :postgres ? :jsonb : :json
    end
  end
end
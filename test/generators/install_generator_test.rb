require_relative "test_case"
require "generators/skadi/install/install_generator"

module Skadi
  module Generators
    class InstallGeneratorTest < TestCase
      tests Skadi::Generators::InstallGenerator
      generates "install_skadi"

      def test_creates_migration_with_expected_class_name
        content = generate_migration

        assert_match(/class InstallSkadi < ActiveRecord::Migration\[\d+\.\d+\]$/, content)
      end

      def test_defaults_to_postgres_db_engine
        content = generate_migration

        # Check for postgres specific column types
        assert_match "t.jsonb", content
        assert_match "t.uuid", content
        assert_match "using: :gin", content
      end

      def test_raises_on_invalid_db_engine
        assert_raises(Skadi::Generators::InstallGenerator::Error) do
          run_generator ["--db-engine=oracle"]
        end
      end
    end
  end
end
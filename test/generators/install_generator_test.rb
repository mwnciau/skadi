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

      def test_creates_intializer
        run_generator

        assert_file "config/initializers/skadi.rb" do |content|
          assert valid_ruby_syntax?(content)
          assert_match(/Skadi.configure/, content)
        end
      end

      def test_auto_detects_db_engine_from_app_config
        content = generate_migration

        # The dummy app is configured to use sqlite3
        assert_match "t.string :visit_token, limit: 36", content
        refute_match "t.uuid", content
        refute_match "using: :gin", content
      end

      def test_raises_on_invalid_db_engine
        assert_raises(Skadi::Generators::InstallGenerator::Error) do
          run_generator [ "--db-engine=oracle" ]
        end
      end
    end
  end
end

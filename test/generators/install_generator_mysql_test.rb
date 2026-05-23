require_relative "test_case"
require "generators/skadi/install/install_generator"

module Skadi
  module Generators
    class InstallGeneratorMysqlTest < TestCase
      tests Skadi::Generators::InstallGenerator
      generates "install_skadi"

      def test_uses_string_with_limit_for_tokens
        content = generate_migration "--db-engine=mysql"

        assert_match(/t\.string :visit_token, limit: 36, null: false$/, content)
        assert_match(/t\.string :tracking_token, limit: 36$/, content)
        assert_match(/t\.string :view_token, limit: 36, null: false$/, content)
      end

      def test_uses_json_for_json_columns
        content = generate_migration "--db-engine=mysql"

        assert_match(/t\.json :query_params$/, content)
        assert_match(/t\.json :properties$/, content)
        refute_match "t.jsonb", content
      end

      def test_does_not_add_gin_index
        content = generate_migration "--db-engine=mysql"

        refute_match "using: :gin", content
      end
    end
  end
end
require_relative "test_case"
require "generators/skadi/install/install_generator"

module Skadi
  module Generators
    class InstallGeneratorPostgresTest < TestCase
      tests Skadi::Generators::InstallGenerator
      generates "install_skadi"

      def test_uses_uuid_columns_for_tokens
        content = generate_migration  "--db-engine=postgres"

        assert_match(/t\.uuid :visit_token, null: false$/, content)
        assert_match(/t\.uuid :tracking_token$/, content)
        assert_match(/t\.uuid :view_token, null: false$/, content)
        refute_match "limit: 36", content
      end

      def test_uses_jsonb_for_json_columns
        content = generate_migration  "--db-engine=postgres"

        assert_match(/t\.jsonb :query_params$/, content)
        assert_match(/t\.jsonb :properties$/, content)
      end

      def test_adds_gin_index_on_event_properties
        content = generate_migration  "--db-engine=postgres"

        assert_match(/add_index :skadi_events, :properties, using: :gin, opclass: :jsonb_path_ops$/, content)
      end
    end
  end
end
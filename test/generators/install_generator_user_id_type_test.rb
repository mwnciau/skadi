require_relative "test_case"
require "generators/skadi/install/install_generator"

module Skadi
  module Generators
    class InstallGeneratorUserIdTypeTest < TestCase
      tests Skadi::Generators::InstallGenerator
      generates "install_skadi"

      def test_default_type_is_bigint
        content = generate_migration

        assert_match "t.references :user, type: :bigint", content
      end

      def test_type_integer
        content = generate_migration "--user-id-type=integer"

        assert_match(/t\.references :user, type: :integer, index: false$/, content)
      end

      def test_type_uuid_on_postgres
        content = generate_migration "--user-id-type=uuid"

        assert_match(/t\.references :user, type: :uuid, index: false$/, content)
      end

      def test_type_uuid_on_mysql_falls_back_to_string
        content = generate_migration "--user-id-type=uuid", "--db-engine=mysql"

        assert_match(/t\.references :user, type: :string, limit: 36, index: false$/, content)
      end

      def test_type_uuid_on_sqlite_falls_back_to_string
        content = generate_migration "--user-id-type=uuid", "--db-engine=sqlite"

        assert_match(/t\.references :user, type: :string, limit: 36, index: false$/, content)
      end

      def test_type_string
        content = generate_migration "--user-id-type=string"

        assert_match(/t\.references :user, type: :string, index: false$/, content)
        refute_match "t.references :user, type: :string, limit: 36", content
      end

      def test_raises_on_invalid_type
        assert_raises(Skadi::Generators::InstallGenerator::Error) do
          run_generator ["--user-id-type=float"]
        end
      end
    end
  end
end

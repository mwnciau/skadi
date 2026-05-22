require "test_helper"
require "generators/skadi/install/install_generator"

class Skadi::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  tests Skadi::Generators::InstallGenerator
  destination File.expand_path("../../tmp", __dir__)
  setup :prepare_destination

  private def generate_migration(*args)
    run_generator(args)

    content = nil
    assert_migration "db/migrate/install_skadi.rb" do |migration_content|
      content = migration_content
    end

    content
  end

  def test_creates_migration_with_expected_class_name
    content = generate_migration

    assert_match(/class InstallSkadi < ActiveRecord::Migration\[\d+\.\d+\]\n/, content)
  end

  # Postgres compatibility

  def test_postgres_uses_uuid_columns_for_tokens
    content = generate_migration

    assert_match(/t\.uuid :visit_token, null: false\n/, content)
    assert_match(/t\.uuid :tracking_token\n/, content)
    assert_match(/t\.uuid :view_token, null: false\n/, content)
    refute_match "limit: 36", content
  end

  def test_postgres_uses_jsonb_for_json_columns
    content = generate_migration

    assert_match(/t\.jsonb :query_params\n/, content)
    assert_match(/t\.jsonb :properties\n/, content)
  end

  def test_postgres_adds_gin_index_on_event_properties
    content = generate_migration

    assert_match(/add_index :skadi_events, :properties, using: :gin, opclass: :jsonb_path_ops\n/, content)
  end

  # MySQL compatibility

  def test_mysql_uses_string_with_limit_for_tokens
    content = generate_migration "--db-engine=mysql"

    assert_match(/t\.string :visit_token, limit: 36, null: false\n/, content)
    assert_match(/t\.string :tracking_token, limit: 36\n/, content)
    assert_match(/t\.string :view_token, limit: 36, null: false\n/, content)
  end

  def test_mysql_uses_json_for_json_columns
    content = generate_migration "--db-engine=mysql"

    assert_match(/t\.json :query_params\n/, content)
    assert_match(/t\.json :properties\n/, content)
    refute_match "t\.jsonb", content
  end

  def test_mysql_does_not_add_gin_index
    content = generate_migration "--db-engine=mysql"

    refute_match "using: :gin", content
  end

  # SQLite compatibility

  def test_sqlite_uses_string_with_limit_for_tokens
    content = generate_migration "--db-engine=sqlite"

    assert_match(/t\.string :visit_token, limit: 36, null: false\n/, content)
    assert_match(/t\.string :view_token, limit: 36, null: false\n/, content)
  end

  def test_sqlite_does_not_add_gin_index
    content = generate_migration "--db-engine=sqlite"

    refute_match(/using: :gin/, content)
  end

  # User ID types

  def test_default_user_id_type_is_bigint
    content = generate_migration

    assert_match(/t\.references :user, type: :bigint, index: false\n/, content)
  end

  def test_user_id_type_integer
    content = generate_migration "--user-id-type=integer"

    assert_match(/t\.references :user, type: :integer, index: false\n/, content)
  end

  def test_user_id_type_uuid_on_postgres
    content = generate_migration "--user-id-type=uuid"

    assert_match(/t\.references :user, type: :uuid, index: false\n/, content)
  end

  def test_user_id_type_uuid_on_mysql_falls_back_to_string
    content = generate_migration "--user-id-type=uuid", "--db-engine=mysql"

    assert_match(/t\.references :user, type: :string, limit: 36, index: false\n/, content)
  end

  def test_user_id_type_uuid_on_sqlite_falls_back_to_string
    content = generate_migration "--user-id-type=uuid", "--db-engine=sqlite"

    assert_match(/t\.references :user, type: :string, limit: 36, index: false\n/, content)
  end

  def test_user_id_type_string
    content = generate_migration "--user-id-type=string"

    assert_match(/t\.references :user, type: :string, index: false\n/, content)
    refute_match "t\.references :user, type: :string, limit: 36", content
  end
end

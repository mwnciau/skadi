require "test_helper"
require "generators/skadi/install_generator"

class Skadi::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  tests Skadi::Generators::InstallGenerator
  destination File.expand_path("../../tmp", __dir__)
  setup :prepare_destination

  def test_creates_migration_with_expected_class_name
    run_generator
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/class InstallSkadi < ActiveRecord::Migration\[\d+\.\d+\]/, content)
    end
  end

  # Postgres compatibility

  def test_postgres_uses_uuid_columns_for_tokens
    run_generator
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.uuid :visit_token, null: false/, content)
      assert_match(/t\.uuid :tracking_token\b/, content)
      assert_match(/t\.uuid :view_token, null: false/, content)
      refute_match(/limit: 36/, content)
    end
  end

  def test_postgres_uses_jsonb_for_json_columns
    run_generator
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.jsonb :query_params/, content)
      assert_match(/t\.jsonb :properties/, content)
    end
  end

  def test_postgres_adds_gin_index_on_event_properties
    run_generator
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(
        /add_index :skadi_events, :properties, using: :gin, opclass: :jsonb_path_ops/,
        content
      )
    end
  end

  # MySQL compatibility

  def test_mysql_uses_string_with_limit_for_tokens
    run_generator %w[--db-engine=mysql]
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.string :visit_token, limit: 36, null: false/, content)
      assert_match(/t\.string :tracking_token, limit: 36/, content)
      assert_match(/t\.string :view_token, limit: 36, null: false/, content)
    end
  end

  def test_mysql_uses_json_for_json_columns
    run_generator %w[--db-engine=mysql]
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.json :query_params/, content)
      assert_match(/t\.json :properties/, content)
      refute_match(/t\.jsonb/, content)
    end
  end

  def test_mysql_does_not_add_gin_index
    run_generator %w[--db-engine=mysql]
    assert_migration "db/migrate/install_skadi.rb" do |content|
      refute_match(/using: :gin/, content)
    end
  end

  # SQLite compatibility

  def test_sqlite_uses_string_with_limit_for_tokens
    run_generator %w[--db-engine=sqlite]
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.string :visit_token, limit: 36, null: false/, content)
      assert_match(/t\.string :view_token, limit: 36, null: false/, content)
    end
  end

  def test_sqlite_does_not_add_gin_index
    run_generator %w[--db-engine=sqlite]
    assert_migration "db/migrate/install_skadi.rb" do |content|
      refute_match(/using: :gin/, content)
    end
  end

  # User ID types

  def test_default_user_id_type_is_bigint
    run_generator
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.references :user, type: :bigint, index: false/, content)
    end
  end

  def test_user_id_type_integer
    run_generator %w[--user-id-type=integer]
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.references :user, type: :integer, index: false/, content)
    end
  end

  def test_user_id_type_uuid_on_postgres
    run_generator %w[--user-id-type=uuid]
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.references :user, type: :uuid, index: false/, content)
    end
  end

  def test_user_id_type_uuid_on_mysql_falls_back_to_string
    run_generator %w[--user-id-type=uuid --db-engine=mysql]
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.references :user, type: :string, limit: 36, index: false/, content)
    end
  end

  def test_user_id_type_uuid_on_sqlite_falls_back_to_string
    run_generator %w[--user-id-type=uuid --db-engine=sqlite]
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.references :user, type: :string, limit: 36, index: false/, content)
    end
  end

  def test_user_id_type_string
    run_generator %w[--user-id-type=string]
    assert_migration "db/migrate/install_skadi.rb" do |content|
      assert_match(/t\.references :user, type: :string, index: false/, content)
      refute_match(/t\.references :user, type: :string, limit: 36/, content)
    end
  end
end

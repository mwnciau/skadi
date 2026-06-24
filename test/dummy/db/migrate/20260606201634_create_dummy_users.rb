class CreateDummyUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :dummy_users do |t|
      t.string :username, null: false

      t.timestamps
    end
  end
end

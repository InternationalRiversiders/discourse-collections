# frozen_string_literal: true

class CreateCollectionsTables < ActiveRecord::Migration[7.0]
  def change
    create_table :collections do |t|
      t.bigint :user_id, null: false
      t.string :title, null: false
      t.text :description
      t.string :background_url
      t.boolean :is_public, null: false, default: true
      t.timestamps
    end
    add_index :collections, :user_id
    add_index :collections, [:is_public, :created_at]
    add_foreign_key :collections, :users

    create_table :collection_items do |t|
      t.bigint :collection_id, null: false
      t.bigint :topic_id, null: false
      t.integer :position, null: false, default: 0
      t.text :note
      t.timestamps
    end
    add_index :collection_items, [:collection_id, :topic_id], unique: true
    add_index :collection_items, [:collection_id, :position]
    add_index :collection_items, :topic_id
    add_foreign_key :collection_items, :collections
    add_foreign_key :collection_items, :topics
  end
end

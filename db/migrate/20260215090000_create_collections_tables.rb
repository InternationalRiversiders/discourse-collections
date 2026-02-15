# frozen_string_literal: true

class CreateCollectionsTables < ActiveRecord::Migration[7.0]
  def change
    create_table :collections do |t|
      t.bigint :creator_user_id, null: false
      t.bigint :owner_user_id, null: false
      t.string :title, null: false
      t.text :description
      t.boolean :recommended, null: false, default: false
      t.timestamps
    end
    add_index :collections, :creator_user_id
    add_index :collections, :owner_user_id
    add_index :collections, :created_at
    add_index :collections, :recommended
    add_foreign_key :collections, :users, column: :creator_user_id
    add_foreign_key :collections, :users, column: :owner_user_id

    create_table :collection_items do |t|
      t.bigint :collection_id, null: false
      t.bigint :topic_id, null: false
      t.bigint :post_id
      t.integer :position, null: false, default: 0
      t.text :note
      t.datetime :collected_at, null: false
      t.bigint :collected_by_user_id, null: false
      t.timestamps
    end
    add_index :collection_items,
              [:collection_id, :topic_id],
              unique: true,
              where: "post_id IS NULL",
              name: "idx_collection_items_unique_topics"
    add_index :collection_items,
              [:collection_id, :post_id],
              unique: true,
              where: "post_id IS NOT NULL",
              name: "idx_collection_items_unique_posts"
    add_index :collection_items, [:collection_id, :position]
    add_index :collection_items, :topic_id
    add_index :collection_items, :post_id
    add_foreign_key :collection_items, :collections
    add_foreign_key :collection_items, :topics
    add_foreign_key :collection_items, :posts
    add_foreign_key :collection_items, :users, column: :collected_by_user_id

    create_table :collection_memberships do |t|
      t.bigint :collection_id, null: false
      t.bigint :user_id, null: false
      t.integer :status, null: false, default: 0
      t.integer :source, null: false, default: 0
      t.bigint :requested_by_user_id
      t.bigint :acted_by_user_id
      t.text :note
      t.timestamps
    end
    add_index :collection_memberships, [:collection_id, :user_id], unique: true
    add_index :collection_memberships, [:collection_id, :status]
    add_index :collection_memberships, [:user_id, :status]
    add_foreign_key :collection_memberships, :collections
    add_foreign_key :collection_memberships, :users
    add_foreign_key :collection_memberships, :users, column: :requested_by_user_id
    add_foreign_key :collection_memberships, :users, column: :acted_by_user_id

    create_table :collection_role_events do |t|
      t.bigint :collection_id, null: false
      t.bigint :actor_user_id, null: false
      t.integer :event_type, null: false
      t.bigint :target_user_id
      t.bigint :from_user_id
      t.bigint :to_user_id
      t.jsonb :metadata, null: false, default: {}
      t.datetime :created_at, null: false
    end
    add_index :collection_role_events, [:collection_id, :created_at]
    add_index :collection_role_events, :event_type
    add_index :collection_role_events, :target_user_id
    add_foreign_key :collection_role_events, :collections
    add_foreign_key :collection_role_events, :users, column: :actor_user_id
    add_foreign_key :collection_role_events, :users, column: :target_user_id
    add_foreign_key :collection_role_events, :users, column: :from_user_id
    add_foreign_key :collection_role_events, :users, column: :to_user_id

    create_table :collection_follows do |t|
      t.bigint :collection_id, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
    add_index :collection_follows, [:collection_id, :user_id], unique: true
    add_index :collection_follows, [:user_id, :created_at]
    add_index :collection_follows, [:collection_id, :created_at]
    add_foreign_key :collection_follows, :collections
    add_foreign_key :collection_follows, :users
  end
end

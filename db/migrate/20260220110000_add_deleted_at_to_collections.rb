# frozen_string_literal: true

class AddDeletedAtToCollections < ActiveRecord::Migration[7.0]
  def change
    add_column :collections, :deleted_at, :datetime

    add_index :collections, :deleted_at
    add_index :collections, [:owner_user_id, :deleted_at], name: "idx_collections_owner_deleted_at"
    add_index :collections, [:creator_user_id, :deleted_at], name: "idx_collections_creator_deleted_at"
  end
end

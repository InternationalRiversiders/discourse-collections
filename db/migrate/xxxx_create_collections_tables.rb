class CreateCollectionsTables < ActiveRecord::Migration[7.0]
  def change
    # 1. 专辑表
    create_table :collections do |t|
      t.integer :user_id, null: false
      t.string :title, null: false
      t.text :description
      t.string :background_url
      t.boolean :is_public, default: true
      t.timestamps
    end
    add_index :collections, :user_id

    # 2. 专辑内容表 (关联 Topic)
    create_table :collection_items do |t|
      t.integer :collection_id, null: false
      t.integer :topic_id, null: false
      t.integer :position, default: 0
      t.text :note # 推荐语
      t.timestamps
    end
    add_index :collection_items, [:collection_id, :topic_id], unique: true
  end
end
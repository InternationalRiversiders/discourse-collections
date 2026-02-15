# frozen_string_literal: true

class CollectionSerializer < ApplicationSerializer
  attributes :id,
             :title,
             :description,
             :background_url,
             :is_public,
             :user_id,
             :username,
             :items_count,
             :created_at,
             :updated_at

  def username
    object.user&.username
  end

  def items_count
    object.collection_items.count
  end
end

# frozen_string_literal: true

class CollectionSerializer < ApplicationSerializer
  attributes :id,
             :title,
             :description,
             :creator_user_id,
             :creator_username,
             :creator_avatar_template,
             :owner_user_id,
             :owner_username,
             :owner_avatar_template,
             :recommended,
             :followers_count,
             :items_count,
             :created_at,
             :updated_at

  def creator_username
    object.creator&.username
  end

  def creator_avatar_template
    object.creator&.avatar_template
  end

  def owner_username
    object.owner&.username
  end

  def owner_avatar_template
    object.owner&.avatar_template
  end

  def items_count
    object.collection_items.count
  end

  def followers_count
    object.collection_follows.count
  end
end

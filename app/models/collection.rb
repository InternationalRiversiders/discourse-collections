# frozen_string_literal: true

class Collection < ActiveRecord::Base
  belongs_to :user
  has_many :collection_items, -> { order(position: :asc, id: :asc) }, dependent: :destroy
  has_many :topics, through: :collection_items

  validates :user_id, presence: true
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2000 }, allow_blank: true

  scope :visible_to, lambda { |user|
    if user
      where("is_public = true OR user_id = ?", user.id)
    else
      where(is_public: true)
    end
  }

  def add_topic(topic_id, note: nil)
    topic = Topic.find_by(id: topic_id)
    raise ActiveRecord::RecordNotFound, "Topic not found" if topic.blank?

    existing_item = collection_items.find_by(topic_id: topic.id)
    if existing_item.present?
      existing_item.errors.add(:topic_id, :taken)
      return existing_item
    end

    collection_items.create(
      topic_id: topic.id,
      note: note,
      position: next_item_position,
    )
  end

  def remove_topic(topic_id)
    item = collection_items.find_by(topic_id: topic_id)
    return false if item.blank?

    transaction do
      item.destroy!
      normalize_item_positions!
    end

    true
  end

  def move_item(item_id, target_position)
    item = collection_items.find(item_id)
    destination = normalize_target_position(target_position.to_i)
    return item if destination == item.position

    transaction do
      if destination < item.position
        collection_items.where(position: destination...item.position).update_all(
          "position = position + 1",
        )
      else
        collection_items.where(position: (item.position + 1)..destination).update_all(
          "position = position - 1",
        )
      end

      item.update!(position: destination)
    end

    item
  end

  def normalize_item_positions!
    collection_items.order(:position, :id).each_with_index do |item, index|
      next if item.position == index
      item.update_columns(position: index)
    end
  end

  private

  def next_item_position
    (collection_items.maximum(:position) || -1) + 1
  end

  def normalize_target_position(position)
    [[position, 0].max, [collection_items.count - 1, 0].max].min
  end
end

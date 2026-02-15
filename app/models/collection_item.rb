# frozen_string_literal: true

class CollectionItem < ActiveRecord::Base
  belongs_to :collection
  belongs_to :topic
  belongs_to :post, optional: true
  belongs_to :collected_by_user, class_name: "User", foreign_key: :collected_by_user_id

  before_validation :set_collected_at, on: :create

  validates :collection_id, presence: true
  validates :topic_id, presence: true
  validates :topic_id,
            uniqueness: {
              scope: :collection_id,
              conditions: -> { where(post_id: nil) },
            },
            if: -> { post_id.blank? }
  validates :post_id,
            uniqueness: {
              scope: :collection_id,
              conditions: -> { where.not(post_id: nil) },
            },
            if: -> { post_id.present? }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :note, length: { maximum: 1000 }, allow_blank: true
  validates :collected_at, presence: true
  validates :collected_by_user_id, presence: true
  validate :validate_post_topic_consistency

  private

  def set_collected_at
    self.collected_at ||= Time.zone.now
  end

  def validate_post_topic_consistency
    return if post_id.blank?
    if post.blank?
      errors.add(:post_id, "is invalid")
      return
    end

    if post.topic_id != topic_id
      errors.add(:post_id, "must belong to the same topic_id")
    end

    if post.post_number == 1
      errors.add(:post_id, "cannot be topic first post; collect by topic instead")
    end
  end
end

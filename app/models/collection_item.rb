# frozen_string_literal: true

class CollectionItem < ActiveRecord::Base
  belongs_to :collection
  belongs_to :topic

  validates :collection_id, presence: true
  validates :topic_id, presence: true
  validates :topic_id, uniqueness: { scope: :collection_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :note, length: { maximum: 1000 }, allow_blank: true
end

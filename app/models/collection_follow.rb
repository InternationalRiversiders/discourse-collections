# frozen_string_literal: true

class CollectionFollow < ActiveRecord::Base
  belongs_to :collection
  belongs_to :user

  validates :collection_id, presence: true
  validates :user_id, presence: true, uniqueness: { scope: :collection_id }
end

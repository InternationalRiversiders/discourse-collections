# frozen_string_literal: true

class CollectionRoleEvent < ActiveRecord::Base
  self.record_timestamps = false

  belongs_to :collection
  belongs_to :actor_user, class_name: "User", foreign_key: :actor_user_id
  belongs_to :target_user, class_name: "User", foreign_key: :target_user_id, optional: true
  belongs_to :from_user, class_name: "User", foreign_key: :from_user_id, optional: true
  belongs_to :to_user, class_name: "User", foreign_key: :to_user_id, optional: true

  enum :event_type, {
    maintainer_invited: 0,
    maintainer_applied: 1,
    maintainer_approved: 2,
    maintainer_removed: 3,
    ownership_transferred: 4,
  }

  validates :collection_id, presence: true
  validates :actor_user_id, presence: true
  validates :event_type, presence: true
  validates :created_at, presence: true
end

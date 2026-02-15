# frozen_string_literal: true

class CollectionMembership < ActiveRecord::Base
  belongs_to :collection
  belongs_to :user
  belongs_to :requested_by_user, class_name: "User", foreign_key: :requested_by_user_id, optional: true
  belongs_to :acted_by_user, class_name: "User", foreign_key: :acted_by_user_id, optional: true

  enum :status, {
    pending: 0,
    invited: 1,
    active: 2,
    removed: 3,
  }

  enum :source, {
    system: 0,
    creator_invitation: 1,
    owner_invitation: 2,
    self_nomination: 3,
  }

  validates :collection_id, presence: true
  validates :user_id, presence: true, uniqueness: { scope: :collection_id }
  validates :note, length: { maximum: 1000 }, allow_blank: true
end

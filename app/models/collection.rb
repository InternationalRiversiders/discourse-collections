# frozen_string_literal: true

class Collection < ActiveRecord::Base
  belongs_to :creator, class_name: "User", foreign_key: :creator_user_id
  belongs_to :owner, class_name: "User", foreign_key: :owner_user_id

  has_many :collection_items, -> { order(position: :asc, id: :asc) }, dependent: :destroy
  has_many :topics, through: :collection_items
  has_many :collection_memberships, dependent: :destroy
  has_many :collection_role_events, dependent: :destroy
  has_many :collection_follows, dependent: :destroy
  has_many :active_collection_memberships,
           -> { where(status: CollectionMembership.statuses[:active]) },
           class_name: "CollectionMembership"
  has_many :maintainers, through: :active_collection_memberships, source: :user
  has_many :followers, through: :collection_follows, source: :user

  after_create :bootstrap_creator_maintainer!

  validates :creator_user_id, presence: true
  validates :owner_user_id, presence: true
  validates :title, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :recommended, inclusion: { in: [true, false] }

  scope :not_deleted, -> { where(deleted_at: nil) }
  scope :latest_first, -> { order(created_at: :desc) }
  scope :recommended_first, -> { not_deleted.where(recommended: true).order(created_at: :desc) }
  scope :for_creator, ->(user_id) { not_deleted.where(creator_user_id: user_id) }
  scope :for_owner, ->(user_id) { not_deleted.where(owner_user_id: user_id) }

  def self.for_maintainer(user_id)
    not_deleted.joins(:collection_memberships).where(
      collection_memberships: {
        user_id: user_id,
        status: CollectionMembership.statuses[:active],
      },
    )
  end

  def self.manageable_by(user_id)
    not_deleted.left_joins(:collection_memberships).where(
      <<~SQL,
        collections.creator_user_id = :user_id
        OR collections.owner_user_id = :user_id
        OR (
          collection_memberships.user_id = :user_id
          AND collection_memberships.status = :active_status
        )
      SQL
      user_id: user_id,
      active_status: CollectionMembership.statuses[:active],
    ).distinct
  end

  def soft_delete!
    return if deleted_at.present?
    update!(deleted_at: Time.zone.now, recommended: false)
  end

  def add_topic(topic_id, note: nil, collected_by_user:)
    topic = Topic.find_by(id: topic_id)
    raise ActiveRecord::RecordNotFound, "Topic not found" if topic.blank?

    existing_item = collection_items.find_by(topic_id: topic.id, post_id: nil)
    if existing_item.present?
      item = collection_items.build(topic_id: topic.id, post_id: nil)
      item.errors.add(:topic_id, :taken, message: "topic already exists in this collection")
      return item
    end

    collection_items.create(
      topic_id: topic.id,
      post_id: nil,
      note: note,
      position: next_item_position,
      collected_by_user_id: collected_by_user.id,
    )
  end

  def add_post(post_id, note: nil, collected_by_user:)
    post = Post.find_by(id: post_id)
    raise ActiveRecord::RecordNotFound, "Post not found" if post.blank?

    existing_item = collection_items.find_by(post_id: post.id)
    if existing_item.present?
      item = collection_items.build(topic_id: post.topic_id, post_id: post.id)
      item.errors.add(:post_id, :taken, message: "post already exists in this collection")
      return item
    end

    collection_items.create(
      topic_id: post.topic_id,
      post_id: post.id,
      note: note,
      position: next_item_position,
      collected_by_user_id: collected_by_user.id,
    )
  end

  def remove_item(item_id)
    item = collection_items.find_by(id: item_id)
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

  def maintainer?(user)
    return false if user.blank?
    return true if user.id == owner_user_id
    collection_memberships.where(user_id: user.id, status: CollectionMembership.statuses[:active]).exists?
  end

  def can_invite_maintainers?(user)
    return false if user.blank?
    user.id == owner_user_id || user.id == creator_user_id
  end

  def followed_by?(user)
    return false if user.blank?
    collection_follows.exists?(user_id: user.id)
  end

  def invite_maintainer!(actor:, user:, note: nil)
    raise Discourse::InvalidAccess if !can_invite_maintainers?(actor)

    membership = collection_memberships.find_or_initialize_by(user_id: user.id)
    membership.assign_attributes(
      status: :active,
      source: actor.id == creator_user_id ? :creator_invitation : :owner_invitation,
      requested_by_user_id: actor.id,
      acted_by_user_id: actor.id,
      note: note.presence || membership.note,
    )
    membership.save!

    log_role_event!(
      event_type: :maintainer_invited,
      actor_user_id: actor.id,
      target_user_id: user.id,
      metadata: { source: membership.source },
    )

    membership
  end

  def apply_for_maintainer!(user:, note: nil)
    membership = collection_memberships.find_or_initialize_by(user_id: user.id)
    raise Discourse::InvalidAccess if membership.active? || user.id == owner_user_id

    membership.assign_attributes(
      status: :pending,
      source: :self_nomination,
      requested_by_user_id: user.id,
      acted_by_user_id: nil,
      note: note,
    )
    membership.save!

    log_role_event!(
      event_type: :maintainer_applied,
      actor_user_id: user.id,
      target_user_id: user.id,
    )

    membership
  end

  def approve_maintainer_application!(actor:, user:)
    raise Discourse::InvalidAccess if actor.id != owner_user_id

    membership = collection_memberships.find_by!(user_id: user.id)
    raise Discourse::InvalidAccess if !membership.pending?

    membership.update!(status: :active, acted_by_user_id: actor.id)

    log_role_event!(
      event_type: :maintainer_approved,
      actor_user_id: actor.id,
      target_user_id: user.id,
    )

    membership
  end

  def reject_maintainer_application!(actor:, user:)
    raise Discourse::InvalidAccess if actor.id != owner_user_id

    membership = collection_memberships.find_by!(user_id: user.id)
    raise Discourse::InvalidAccess if !membership.pending?

    membership.update!(status: :removed, acted_by_user_id: actor.id)

    log_role_event!(
      event_type: :maintainer_removed,
      actor_user_id: actor.id,
      target_user_id: user.id,
      metadata: { reason: "application_rejected" },
    )

    membership
  end

  def remove_maintainer!(actor:, user:)
    raise Discourse::InvalidAccess if actor.id != owner_user_id
    raise Discourse::InvalidAccess if user.id == creator_user_id
    raise Discourse::InvalidAccess if user.id == owner_user_id

    membership = collection_memberships.find_by!(user_id: user.id)
    raise Discourse::InvalidAccess if !membership.active?

    membership.update!(status: :removed, acted_by_user_id: actor.id)

    log_role_event!(
      event_type: :maintainer_removed,
      actor_user_id: actor.id,
      target_user_id: user.id,
    )

    membership
  end

  def transfer_ownership!(actor:, new_owner:)
    raise Discourse::InvalidAccess if actor.id != owner_user_id
    raise Discourse::InvalidAccess if new_owner.id == owner_user_id

    previous_owner_id = owner_user_id
    transaction do
      update!(owner_user_id: new_owner.id)

      membership = collection_memberships.find_or_initialize_by(user_id: new_owner.id)
      membership.assign_attributes(
        status: :active,
        source: :system,
        requested_by_user_id: actor.id,
        acted_by_user_id: actor.id,
      )
      membership.save!

      log_role_event!(
        event_type: :ownership_transferred,
        actor_user_id: actor.id,
        from_user_id: previous_owner_id,
        to_user_id: new_owner.id,
        target_user_id: new_owner.id,
      )
    end
  end

  def follow!(user)
    collection_follows.find_or_create_by!(user_id: user.id)
  end

  def unfollow!(user)
    collection_follows.where(user_id: user.id).destroy_all
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

  def bootstrap_creator_maintainer!
    collection_memberships.create!(
      user_id: creator_user_id,
      status: :active,
      source: :system,
      requested_by_user_id: creator_user_id,
      acted_by_user_id: creator_user_id,
    )
  end

  def log_role_event!(event_type:, actor_user_id:, target_user_id: nil, from_user_id: nil, to_user_id: nil, metadata: {})
    collection_role_events.create!(
      event_type: event_type,
      actor_user_id: actor_user_id,
      target_user_id: target_user_id,
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      metadata: metadata,
      created_at: Time.zone.now,
    )
  end
end

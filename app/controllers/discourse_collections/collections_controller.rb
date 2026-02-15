# frozen_string_literal: true
require "set"

module DiscourseCollections
  class CollectionsController < ::ApplicationController
    requires_plugin "discourse-collections"

    PLAZA_FILTERS = %w[latest most_followed recommended].freeze
    INDEX_CACHE_TTL = 2.minutes
    BY_USER_CACHE_TTL = 2.minutes
    MINE_CACHE_TTL = 45.seconds
    SHOW_CACHE_TTL = 2.minutes
    ROLE_EVENTS_CACHE_TTL = 1.minute

    before_action :ensure_logged_in,
                  only: [
                    :create,
                    :update,
                    :mine,
                    :add_item,
                    :remove_item,
                    :move_item,
                    :invite_maintainer,
                    :apply_maintainer,
                    :approve_maintainer,
                    :reject_maintainer,
                    :remove_maintainer,
                    :transfer_ownership,
                    :follow,
                    :unfollow,
                    :set_recommended,
                  ]
    before_action :find_collection,
                  only: [
                    :show,
                    :update,
                    :add_item,
                    :remove_item,
                    :move_item,
                    :invite_maintainer,
                    :apply_maintainer,
                    :approve_maintainer,
                    :reject_maintainer,
                    :remove_maintainer,
                    :transfer_ownership,
                    :role_events,
                    :follow,
                    :unfollow,
                    :set_recommended,
                  ]
    before_action :ensure_maintainer!, only: [:add_item, :remove_item, :move_item]
    before_action :ensure_owner!,
                  only: [
                    :approve_maintainer,
                    :reject_maintainer,
                    :remove_maintainer,
                    :transfer_ownership,
                  ]
    before_action :ensure_manager!, only: [:update, :invite_maintainer]
    before_action :ensure_staff!, only: [:set_recommended]

    def index
      filter = normalized_filter
      q = params[:q].to_s.strip
      limit = limit_param

      payload =
        Discourse.cache.fetch(
          DiscourseCollections::Cache.plaza_key(filter: filter, q: q, limit: limit),
          expires_in: INDEX_CACHE_TTL,
        ) do
          collections = base_plaza_scope
          collections = apply_filter(collections, filter)
          collections = apply_search(collections, q)
          collections = collections.limit(limit).to_a

          {
            collections:
              serialize_collections(
                collections,
                viewer: nil,
                contains_topic_id: nil,
                contains_post_id: nil,
              ),
          }
        end

      render_json_dump(
        collections:
          apply_current_user_overlay(
            payload[:collections],
            contains_topic_id: nil,
            contains_post_id: nil,
          ),
      )
    end

    def mine
      contains_topic_id = params[:contains_topic_id].presence&.to_i
      contains_post_id = params[:contains_post_id].presence&.to_i
      q = params[:q].to_s.strip
      limit = limit_param

      payload =
        Discourse.cache.fetch(
          DiscourseCollections::Cache.mine_key(
            user_id: current_user.id,
            q: q,
            limit: limit,
            contains_topic_id: contains_topic_id,
            contains_post_id: contains_post_id,
          ),
          expires_in: MINE_CACHE_TTL,
        ) do
          collections = Collection.manageable_by(current_user.id).includes(:creator, :owner)
          collections = apply_search(collections, q)
          collections = collections.latest_first.limit(limit).to_a
          {
            collections:
              serialize_collections(
                collections,
                viewer: current_user,
                contains_topic_id: contains_topic_id,
                contains_post_id: contains_post_id,
              ),
          }
        end

      render_json_dump(collections: payload[:collections])
    end

    def by_user
      user = fetch_user
      q = params[:q].to_s.strip
      limit = limit_param

      payload =
        Discourse.cache.fetch(
          DiscourseCollections::Cache.by_user_key(user_id: user.id, q: q, limit: limit),
          expires_in: BY_USER_CACHE_TTL,
        ) do
          collections = Collection.for_creator(user.id).includes(:creator, :owner).latest_first.limit(limit)
          collections = apply_search(collections, q)
          collections = collections.to_a
          {
            collections:
              serialize_collections(
                collections,
                viewer: nil,
                contains_topic_id: nil,
                contains_post_id: nil,
              ),
          }
        end

      render_json_dump(
        collections:
          apply_current_user_overlay(
            payload[:collections],
            contains_topic_id: nil,
            contains_post_id: nil,
          ),
      )
    end

    def create
      if current_user.trust_level < SiteSetting.min_trust_level_to_create_collection.to_i
        return render_json_error("Your trust level is too low to create a collection", status: 403)
      end

      if Collection.where(creator_user_id: current_user.id).count >= SiteSetting.max_collections_per_user.to_i
        return render_json_error("You have reached the collection limit", status: 422)
      end

      collection = Collection.new(collection_params)
      collection.creator = current_user
      collection.owner = current_user

      if collection.save
        touch_collection_cache!(collection.id)
        render_json_dump(collection: serialize_collection(collection))
      else
        render_json_error(collection)
      end
    end

    def update
      if @collection.update(collection_params)
        touch_collection_cache!(@collection.id)
        render_json_dump(collection: serialize_collection(@collection.reload))
      else
        render_json_error(@collection)
      end
    end

    def show
      payload =
        Discourse.cache.fetch(
          DiscourseCollections::Cache.show_key(collection_id: @collection.id),
          expires_in: SHOW_CACHE_TTL,
        ) do
          collection_items = @collection.collection_items.includes(:topic, :post, :collected_by_user)
          {
            collection:
              serialize_collection(
                @collection,
                include_items: true,
                collection_items: collection_items,
                viewer: nil,
                contains_topic_id: nil,
                contains_post_id: nil,
              ),
          }
        end

      render_json_dump(
        collection:
          apply_current_user_overlay_to_collection(
            payload[:collection],
            contains_topic_id: nil,
            contains_post_id: nil,
          ),
      )
    end

    def add_item
      item =
        if params[:post_id].present?
          @collection.add_post(
            params.require(:post_id),
            note: params[:note],
            collected_by_user: current_user,
          )
        else
          @collection.add_topic(
            params.require(:topic_id),
            note: params[:note],
            collected_by_user: current_user,
          )
        end

      if item.errors.added?(:topic_id, :taken) || item.errors.added?(:post_id, :taken)
        render_json_error("Item already exists in this collection", status: 422)
      elsif item.persisted?
        touch_collection_cache!(@collection.id)
        notify_collected_author(item)
        render_json_dump(item: serialize_item(item))
      else
        render_json_error(item)
      end
    end

    def remove_item
      removed = @collection.remove_item(params[:item_id])
      raise ActiveRecord::RecordNotFound if !removed
      touch_collection_cache!(@collection.id)
      render json: success_json
    end

    def move_item
      position = params.require(:position).to_i
      item = @collection.move_item(params[:item_id], position)
      touch_collection_cache!(@collection.id)
      render_json_dump(item: serialize_item(item))
    end

    def invite_maintainer
      user = resolve_user!(id_key: :user_id, username_key: :username)
      membership = @collection.invite_maintainer!(actor: current_user, user: user, note: params[:note])
      touch_collection_cache!(@collection.id)
      render_json_dump(membership: serialize_membership(membership))
    end

    def apply_maintainer
      membership = @collection.apply_for_maintainer!(user: current_user, note: params[:note])
      touch_collection_cache!(@collection.id)
      render_json_dump(membership: serialize_membership(membership))
    end

    def approve_maintainer
      user = User.find(params.require(:user_id))
      membership = @collection.approve_maintainer_application!(actor: current_user, user: user)
      touch_collection_cache!(@collection.id)
      render_json_dump(membership: serialize_membership(membership))
    end

    def reject_maintainer
      user = User.find(params.require(:user_id))
      membership = @collection.reject_maintainer_application!(actor: current_user, user: user)
      touch_collection_cache!(@collection.id)
      render_json_dump(membership: serialize_membership(membership))
    end

    def remove_maintainer
      user = User.find(params.require(:user_id))
      membership = @collection.remove_maintainer!(actor: current_user, user: user)
      touch_collection_cache!(@collection.id)
      render_json_dump(membership: serialize_membership(membership))
    end

    def transfer_ownership
      new_owner = resolve_user!(id_key: :new_owner_user_id, username_key: :new_owner_username)
      @collection.transfer_ownership!(actor: current_user, new_owner: new_owner)
      @collection.reload
      touch_collection_cache!(@collection.id)
      render_json_dump(collection: serialize_collection(@collection))
    end

    def role_events
      limit = limit_param
      payload =
        Discourse.cache.fetch(
          DiscourseCollections::Cache.role_events_key(collection_id: @collection.id, limit: limit),
          expires_in: ROLE_EVENTS_CACHE_TTL,
        ) do
          events =
            @collection
              .collection_role_events
              .includes(:actor_user, :target_user, :from_user, :to_user)
              .order(created_at: :desc)
              .limit(limit)
          { role_events: events.map { |event| serialize_role_event(event) } }
        end

      render_json_dump(role_events: payload[:role_events])
    end

    def follow
      follow = @collection.follow!(current_user)
      touch_collection_cache!(@collection.id)
      render_json_dump(
        follow: {
          id: follow.id,
          collection_id: follow.collection_id,
          user_id: follow.user_id,
          created_at: follow.created_at,
        },
      )
    end

    def unfollow
      @collection.unfollow!(current_user)
      touch_collection_cache!(@collection.id)
      render json: success_json
    end

    def set_recommended
      value = ActiveModel::Type::Boolean.new.cast(params.require(:recommended))
      @collection.update!(recommended: value)
      touch_collection_cache!(@collection.id)
      render_json_dump(collection: serialize_collection(@collection.reload))
    end

    private

    def find_collection
      @collection = Collection.includes(:creator, :owner).find(params[:id])
    end

    def base_plaza_scope
      Collection.includes(:creator, :owner)
    end

    def apply_filter(scope, filter = normalized_filter)
      return scope.latest_first if !PLAZA_FILTERS.include?(filter)

      case filter
      when "recommended"
        scope.recommended_first
      when "most_followed"
        scope
          .left_joins(:collection_follows)
          .group("collections.id")
          .order(Arel.sql("COUNT(collection_follows.id) DESC"), Arel.sql("collections.created_at DESC"))
      else
        scope.latest_first
      end
    end

    def apply_search(scope, q = params[:q].to_s.strip)
      return scope if q.blank?
      scope.where("collections.title ILIKE :q OR collections.description ILIKE :q", q: "%#{q}%")
    end

    def normalized_filter
      filter = params[:filter].presence || "latest"
      return "latest" if !PLAZA_FILTERS.include?(filter)
      filter
    end

    def fetch_user
      if params[:username].present?
        User.find_by!(username_lower: params[:username].downcase)
      else
        User.find(params.require(:user_id))
      end
    end

    def resolve_user!(id_key:, username_key:)
      if params[id_key].present?
        User.find(params[id_key].to_i)
      elsif params[username_key].present?
        User.find_by!(username_lower: params[username_key].to_s.downcase)
      else
        raise ActionController::ParameterMissing, id_key
      end
    end

    def ensure_owner!
      raise Discourse::InvalidAccess if @collection.owner_user_id != current_user.id
    end

    def ensure_staff!
      raise Discourse::InvalidAccess if !current_user&.staff?
    end

    def ensure_manager!
      raise Discourse::InvalidAccess if !@collection.can_invite_maintainers?(current_user)
    end

    def ensure_maintainer!
      raise Discourse::InvalidAccess if !@collection.maintainer?(current_user)
    end

    def limit_param
      [[params.fetch(:limit, 50).to_i, 1].max, 100].min
    end

    def serialize_collection(
      collection,
      include_items: false,
      collection_items: nil,
      stats: nil,
      viewer: current_user,
      contains_topic_id: nil,
      contains_post_id: nil
    )
      items_count = stats&.fetch(:items_count, nil)
      items_count = collection.collection_items.count if items_count.nil?
      followers_count = stats&.fetch(:followers_count, nil)
      followers_count = collection.collection_follows.count if followers_count.nil?
      current_user_is_maintainer = stats&.fetch(:current_user_is_maintainer, nil)
      current_user_is_maintainer = collection.maintainer?(viewer) if current_user_is_maintainer.nil?
      followed_by_current_user = stats&.fetch(:followed_by_current_user, nil)
      followed_by_current_user = collection.followed_by?(viewer) if followed_by_current_user.nil?
      maintainers_count = stats&.fetch(:maintainers_count, nil)
      maintainers_count =
        collection.collection_memberships.where(status: CollectionMembership.statuses[:active]).count if maintainers_count.nil?
      already_contains = stats&.fetch(:already_contains, nil)
      if already_contains.nil?
        already_contains =
          already_contains_target?(
            collection,
            contains_topic_id: contains_topic_id,
            contains_post_id: contains_post_id,
          )
      end

      payload = {
        id: collection.id,
        title: collection.title,
        description: collection.description,
        creator_user_id: collection.creator_user_id,
        creator_username: collection.creator&.username,
        creator_avatar_template: collection.creator&.avatar_template,
        owner_user_id: collection.owner_user_id,
        owner_username: collection.owner&.username,
        owner_avatar_template: collection.owner&.avatar_template,
        created_at: collection.created_at,
        updated_at: collection.updated_at,
        recommended: collection.recommended,
        items_count: items_count,
        followers_count: followers_count,
        followed_by_current_user: followed_by_current_user,
        current_user_can_manage: viewer.present? && collection.owner_user_id == viewer.id,
        current_user_can_invite:
          viewer.present? && collection.can_invite_maintainers?(viewer),
        current_user_is_maintainer: current_user_is_maintainer,
        current_user_can_apply_maintainer: viewer.present? && !current_user_is_maintainer && collection.owner_user_id != viewer.id,
        already_contains: already_contains,
        maintainers_count: maintainers_count,
      }

      if include_items
        items = collection_items || collection.collection_items.includes(:topic)
        payload[:items] = items.map { |item| serialize_item(item) }
        payload[:maintainers] =
          collection
            .collection_memberships
            .includes(:user)
            .where(status: CollectionMembership.statuses[:active])
            .map { |membership| serialize_membership(membership) }
        payload[:pending_applications] =
          collection
            .collection_memberships
            .includes(:user)
            .where(status: CollectionMembership.statuses[:pending])
            .map { |membership| serialize_membership(membership) }
      end

      payload
    end

    def serialize_collections(collections, viewer: current_user, contains_topic_id: nil, contains_post_id: nil)
      stats_by_collection_id =
        preload_collection_stats(
          collections,
          viewer: viewer,
          contains_topic_id: contains_topic_id,
          contains_post_id: contains_post_id,
        )
      collections.map do |collection|
        serialize_collection(
          collection,
          stats: stats_by_collection_id[collection.id],
          viewer: viewer,
          contains_topic_id: contains_topic_id,
          contains_post_id: contains_post_id,
        )
      end
    end

    def preload_collection_stats(collections, viewer: nil, contains_topic_id: nil, contains_post_id: nil)
      ids = collections.map(&:id)
      return {} if ids.blank?

      active_status = CollectionMembership.statuses[:active]
      stats_by_id = {}
      ids.each do |collection_id|
        stats_by_id[collection_id] = {
          items_count: 0,
          followers_count: 0,
          maintainers_count: 0,
          followed_by_current_user: false,
          current_user_is_maintainer: false,
          already_contains: nil,
        }
      end

      CollectionItem.where(collection_id: ids).group(:collection_id).count.each do |collection_id, count|
        stats_by_id[collection_id][:items_count] = count
      end

      CollectionFollow.where(collection_id: ids).group(:collection_id).count.each do |collection_id, count|
        stats_by_id[collection_id][:followers_count] = count
      end

      CollectionMembership.where(collection_id: ids, status: active_status).group(:collection_id).count.each do |collection_id, count|
        stats_by_id[collection_id][:maintainers_count] = count
      end

      if viewer.present?
        followed_ids = CollectionFollow.where(collection_id: ids, user_id: viewer.id).pluck(:collection_id).to_set
        membership_ids =
          CollectionMembership.where(collection_id: ids, user_id: viewer.id, status: active_status).pluck(
            :collection_id,
          ).to_set

        collections.each do |collection|
          stats_by_id[collection.id][:followed_by_current_user] = followed_ids.include?(collection.id)
          stats_by_id[collection.id][:current_user_is_maintainer] =
            collection.owner_user_id == viewer.id || membership_ids.include?(collection.id)
        end
      end

      contains_ids = nil
      if contains_post_id.present?
        contains_ids = CollectionItem.where(collection_id: ids, post_id: contains_post_id).pluck(:collection_id).to_set
      elsif contains_topic_id.present?
        contains_ids =
          CollectionItem.where(collection_id: ids, topic_id: contains_topic_id, post_id: nil).pluck(
            :collection_id,
          ).to_set
      end

      if contains_ids.present?
        ids.each do |collection_id|
          stats_by_id[collection_id][:already_contains] = contains_ids.include?(collection_id)
        end
      end

      stats_by_id
    end

    def serialize_item(item)
      topic = item.topic
      {
        id: item.id,
        target_type: item.post_id.present? ? "post" : "topic",
        topic_id: item.topic_id,
        post_id: item.post_id,
        position: item.position,
        note: item.note,
        collected_at: item.collected_at,
        collected_by_user_id: item.collected_by_user_id,
        collected_by_username: item.collected_by_user&.username,
        created_at: item.created_at,
        updated_at: item.updated_at,
        topic: {
          id: topic&.id,
          title: topic&.title,
          slug: topic&.slug,
          posts_count: topic&.posts_count,
          like_count: topic&.like_count,
          views: topic&.views,
        },
        post:
          if item.post.present?
            {
              id: item.post.id,
              post_number: item.post.post_number,
              topic_id: item.post.topic_id,
              excerpt: item.post.excerpt(200),
            }
          end,
      }
    end

    def serialize_membership(membership)
      {
        id: membership.id,
        user_id: membership.user_id,
        username: membership.user&.username,
        user_avatar_template: membership.user&.avatar_template,
        status: membership.status,
        source: membership.source,
        note: membership.note,
        requested_by_user_id: membership.requested_by_user_id,
        acted_by_user_id: membership.acted_by_user_id,
        created_at: membership.created_at,
        updated_at: membership.updated_at,
      }
    end

    def serialize_role_event(event)
      {
        id: event.id,
        event_type: event.event_type,
        actor_user_id: event.actor_user_id,
        actor_username: event.actor_user&.username,
        target_user_id: event.target_user_id,
        target_username: event.target_user&.username,
        from_user_id: event.from_user_id,
        from_username: event.from_user&.username,
        to_user_id: event.to_user_id,
        to_username: event.to_user&.username,
        metadata: event.metadata,
        created_at: event.created_at,
      }
    end

    def notify_collected_author(item)
      target_user = item.post&.user || item.topic&.user
      return if target_user.blank?
      return if target_user.id == current_user.id

      Notification.create!(
        notification_type: Notification.types[:custom],
        user_id: target_user.id,
        topic_id: item.topic_id,
        post_number: item.post&.post_number || 1,
        data: {
          message: "collections.notifications.collected",
          title: "collections.notifications.title",
          collection_id: @collection.id,
          collection_title: @collection.title,
          username: current_user.username,
        }.to_json,
      )
    end

    def already_contains_target?(collection, contains_topic_id:, contains_post_id:)
      return nil if contains_topic_id.blank? && contains_post_id.blank?

      if contains_post_id.present?
        collection.collection_items.exists?(post_id: contains_post_id)
      else
        collection.collection_items.exists?(topic_id: contains_topic_id, post_id: nil)
      end
    end

    def apply_current_user_overlay(collections_payload, contains_topic_id:, contains_post_id:)
      return collections_payload if current_user.blank? || collections_payload.blank?

      collection_ids = collections_payload.map { |payload| payload[:id] }
      active_status = CollectionMembership.statuses[:active]

      followed_ids =
        CollectionFollow.where(collection_id: collection_ids, user_id: current_user.id).pluck(:collection_id).to_set
      membership_ids =
        CollectionMembership.where(collection_id: collection_ids, user_id: current_user.id, status: active_status).pluck(
          :collection_id,
        ).to_set

      contains_ids = nil
      if contains_post_id.present?
        contains_ids =
          CollectionItem.where(collection_id: collection_ids, post_id: contains_post_id).pluck(:collection_id).to_set
      elsif contains_topic_id.present?
        contains_ids =
          CollectionItem.where(collection_id: collection_ids, topic_id: contains_topic_id, post_id: nil).pluck(
            :collection_id,
          ).to_set
      end

      collections_payload.map do |payload|
        owner_user_id = payload[:owner_user_id]
        creator_user_id = payload[:creator_user_id]
        current_user_is_maintainer =
          owner_user_id == current_user.id || membership_ids.include?(payload[:id])

        payload.merge(
          followed_by_current_user: followed_ids.include?(payload[:id]),
          current_user_is_maintainer: current_user_is_maintainer,
          current_user_can_manage: owner_user_id == current_user.id,
          current_user_can_invite: owner_user_id == current_user.id || creator_user_id == current_user.id,
          current_user_can_apply_maintainer: !current_user_is_maintainer && owner_user_id != current_user.id,
          already_contains:
            if contains_ids.present?
              contains_ids.include?(payload[:id])
            else
              payload[:already_contains]
            end,
        )
      end
    end

    def apply_current_user_overlay_to_collection(collection_payload, contains_topic_id:, contains_post_id:)
      return collection_payload if collection_payload.blank?
      apply_current_user_overlay(
        [collection_payload],
        contains_topic_id: contains_topic_id,
        contains_post_id: contains_post_id,
      ).first
    end

    def touch_collection_cache!(collection_id)
      DiscourseCollections::Cache.touch_collection!(collection_id)
    end

    def collection_params
      params.require(:collection).permit(:title, :description)
    end
  end
end

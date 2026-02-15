# frozen_string_literal: true

module DiscourseCollections
  class CollectionsController < ::ApplicationController
    requires_plugin "discourse-collections"

    PLAZA_FILTERS = %w[latest most_followed recommended].freeze

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
      collections = base_plaza_scope
      collections = apply_filter(collections)
      collections = apply_search(collections)
      collections = collections.limit(limit_param)

      render_json_dump(collections: collections.map { |collection| serialize_collection(collection) })
    end

    def mine
      @contains_target_topic_id = params[:contains_topic_id].presence&.to_i
      @contains_target_post_id = params[:contains_post_id].presence&.to_i

      collections = Collection.manageable_by(current_user.id).includes(:creator, :owner)
      collections = apply_search(collections)
      collections = collections.latest_first.limit(limit_param)
      render_json_dump(collections: collections.map { |collection| serialize_collection(collection) })
    end

    def by_user
      user = fetch_user
      collections = Collection.for_creator(user.id).latest_first.limit(limit_param)
      collections = apply_search(collections)
      render_json_dump(collections: collections.map { |collection| serialize_collection(collection) })
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
        render_json_dump(collection: serialize_collection(collection))
      else
        render_json_error(collection)
      end
    end

    def update
      if @collection.update(collection_params)
        render_json_dump(collection: serialize_collection(@collection.reload))
      else
        render_json_error(@collection)
      end
    end

    def show
      collection_items = @collection.collection_items.includes(:topic, :post, :collected_by_user)

      render_json_dump(
        collection: serialize_collection(@collection, include_items: true, collection_items: collection_items),
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
        notify_collected_author(item)
        render_json_dump(item: serialize_item(item))
      else
        render_json_error(item)
      end
    end

    def remove_item
      removed = @collection.remove_item(params[:item_id])
      raise ActiveRecord::RecordNotFound if !removed
      render json: success_json
    end

    def move_item
      position = params.require(:position).to_i
      item = @collection.move_item(params[:item_id], position)
      render_json_dump(item: serialize_item(item))
    end

    def invite_maintainer
      user = resolve_user!(id_key: :user_id, username_key: :username)
      membership = @collection.invite_maintainer!(actor: current_user, user: user, note: params[:note])
      render_json_dump(membership: serialize_membership(membership))
    end

    def apply_maintainer
      membership = @collection.apply_for_maintainer!(user: current_user, note: params[:note])
      render_json_dump(membership: serialize_membership(membership))
    end

    def approve_maintainer
      user = User.find(params.require(:user_id))
      membership = @collection.approve_maintainer_application!(actor: current_user, user: user)
      render_json_dump(membership: serialize_membership(membership))
    end

    def reject_maintainer
      user = User.find(params.require(:user_id))
      membership = @collection.reject_maintainer_application!(actor: current_user, user: user)
      render_json_dump(membership: serialize_membership(membership))
    end

    def remove_maintainer
      user = User.find(params.require(:user_id))
      membership = @collection.remove_maintainer!(actor: current_user, user: user)
      render_json_dump(membership: serialize_membership(membership))
    end

    def transfer_ownership
      new_owner = resolve_user!(id_key: :new_owner_user_id, username_key: :new_owner_username)
      @collection.transfer_ownership!(actor: current_user, new_owner: new_owner)
      @collection.reload
      render_json_dump(collection: serialize_collection(@collection))
    end

    def role_events
      events =
        @collection
          .collection_role_events
          .includes(:actor_user, :target_user, :from_user, :to_user)
          .order(created_at: :desc)
          .limit(limit_param)

      render_json_dump(role_events: events.map { |event| serialize_role_event(event) })
    end

    def follow
      follow = @collection.follow!(current_user)
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
      render json: success_json
    end

    def set_recommended
      value = ActiveModel::Type::Boolean.new.cast(params.require(:recommended))
      @collection.update!(recommended: value)
      render_json_dump(collection: serialize_collection(@collection.reload))
    end

    private

    def find_collection
      @collection = Collection.includes(:creator, :owner).find(params[:id])
    end

    def base_plaza_scope
      Collection.includes(:creator, :owner)
    end

    def apply_filter(scope)
      filter = params[:filter].presence || "latest"
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

    def apply_search(scope)
      q = params[:q].to_s.strip
      return scope if q.blank?
      scope.where("collections.title ILIKE :q OR collections.description ILIKE :q", q: "%#{q}%")
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

    def serialize_collection(collection, include_items: false, collection_items: nil)
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
        items_count: collection.collection_items.count,
        followers_count: collection.collection_follows.count,
        followed_by_current_user: collection.followed_by?(current_user),
        current_user_can_manage: current_user.present? && collection.owner_user_id == current_user.id,
        current_user_can_invite:
          current_user.present? && collection.can_invite_maintainers?(current_user),
        current_user_is_maintainer: collection.maintainer?(current_user),
        current_user_can_apply_maintainer:
          current_user.present? &&
            !collection.maintainer?(current_user) &&
            collection.owner_user_id != current_user.id,
        already_contains: already_contains_target?(collection),
        maintainers_count:
          collection.collection_memberships.where(status: CollectionMembership.statuses[:active]).count,
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

    def already_contains_target?(collection)
      return nil if @contains_target_topic_id.blank? && @contains_target_post_id.blank?

      if @contains_target_post_id.present?
        collection.collection_items.exists?(post_id: @contains_target_post_id)
      else
        collection.collection_items.exists?(topic_id: @contains_target_topic_id, post_id: nil)
      end
    end

    def collection_params
      params.require(:collection).permit(:title, :description)
    end
  end
end

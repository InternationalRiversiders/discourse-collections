# frozen_string_literal: true

module DiscourseCollections
  class CollectionsController < ::ApplicationController
    requires_plugin "discourse-collections"
    before_action :ensure_logged_in, only: [:create, :add_item, :remove_item, :move_item]
    before_action :find_collection, only: [:show, :add_item, :remove_item, :move_item]
    before_action :ensure_owner!, only: [:add_item, :remove_item, :move_item]

    def index
      collections =
        Collection
          .where(is_public: true)
          .includes(:user)
          .order(created_at: :desc)
          .limit(limit_param)

      render_json_dump(collections: collections.map { |collection| serialize_collection(collection) })
    end

    def create
      if current_user.trust_level < SiteSetting.min_trust_level_to_create_collection.to_i
        return render_json_error("Your trust level is too low to create a collection", status: 403)
      end

      if Collection.where(user_id: current_user.id).count >= SiteSetting.max_collections_per_user.to_i
        return render_json_error("You have reached the collection limit", status: 422)
      end

      collection = Collection.new(collection_params)
      collection.user = current_user

      if collection.save
        render_json_dump(collection: serialize_collection(collection))
      else
        render_json_error(collection)
      end
    end

    def show
      raise Discourse::InvalidAccess if !@collection.is_public && @collection.user_id != current_user&.id

      collection_items = @collection.collection_items.includes(:topic)

      render_json_dump(
        collection: serialize_collection(@collection, include_items: true, collection_items: collection_items),
      )
    end

    def add_item
      item = @collection.add_topic(params.require(:topic_id), note: params[:note])

      if item.persisted?
        render_json_dump(item: serialize_item(item))
      elsif item.errors.added?(:topic_id, :taken)
        render_json_error("Topic already exists in this collection", status: 422)
      else
        render_json_error(item)
      end
    end

    def remove_item
      item = @collection.collection_items.find_by(id: params[:item_id])
      raise ActiveRecord::RecordNotFound if item.blank?

      topic_id = item.topic_id
      @collection.remove_topic(topic_id)
      render json: success_json
    end

    def move_item
      position = params.require(:position).to_i
      item = @collection.move_item(params[:item_id], position)
      render_json_dump(item: serialize_item(item))
    end

    private

    def find_collection
      @collection = Collection.includes(:user).find(params[:id])
    end

    def ensure_owner!
      raise Discourse::InvalidAccess if @collection.user_id != current_user.id
    end

    def limit_param
      [[params.fetch(:limit, 50).to_i, 1].max, 100].min
    end

    def serialize_collection(collection, include_items: false, collection_items: nil)
      payload = {
        id: collection.id,
        title: collection.title,
        description: collection.description,
        background_url: collection.background_url,
        is_public: collection.is_public,
        user_id: collection.user_id,
        username: collection.user&.username,
        created_at: collection.created_at,
        updated_at: collection.updated_at,
        items_count: collection.collection_items.count,
      }

      if include_items
        items = collection_items || collection.collection_items.includes(:topic)
        payload[:items] = items.map { |item| serialize_item(item) }
      end

      payload
    end

    def serialize_item(item)
      topic = item.topic
      {
        id: item.id,
        topic_id: item.topic_id,
        position: item.position,
        note: item.note,
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
      }
    end

    def collection_params
      params.require(:collection).permit(:title, :description, :background_url, :is_public)
    end
  end
end

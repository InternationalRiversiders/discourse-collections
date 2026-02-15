module DiscourseCollections
  class CollectionsController < ::ApplicationController
    requires_plugin 'discourse-collections'
    before_action :ensure_logged_in, only: [:create, :add_topic]

    def index
      # 获取所有公开专辑
      collections = Collection.where(is_public: true).order(created_at: :desc).limit(50)
      render_json_dump(collections: collections)
    end

    def create
      # 创建新专辑
      collection = Collection.new(collection_params)
      collection.user = current_user
      if collection.save
        render_json_dump(collection)
      else
        render_json_error(collection)
      end
    end

    def add_topic
      # 把帖子加入专辑
      collection = Collection.find(params[:id])

      # 鉴权：只有创建者能加
      if collection.user_id != current_user.id
        return render_json_error("You don't have permission")
      end

      item = collection.collection_items.build(topic_id: params[:topic_id])

      if item.save
        render json: success_json
      else
        render_json_error(item)
      end
    end

    private

    def collection_params
      params.require(:collection).permit(:title, :description, :is_public)
    end
  end
end
# name: discourse-collections
# about: Adds a "Collections" feature similar to Discuz! Tao Album
# version: 0.1
# authors: YourName
# url: https://github.com/yourname/discourse-collections

enabled_site_setting :collections_enabled

register_asset 'stylesheets/collections.scss'

after_initialize do
  # 加载后端文件
  module ::DiscourseCollections
    class Engine < ::Rails::Engine
      engine_name "discourse_collections"
      isolate_namespace DiscourseCollections
    end
  end

  # 定义后端路由
  Discourse::Application.routes.draw do
    mount ::DiscourseCollections::Engine, at: "/collections"
  end

  DiscourseCollections::Engine.routes.draw do
    get "/" => "collections#index"
    post "/" => "collections#create"
    post "/:id/add_topic" => "collections#add_topic"
  end

  # 扩展 User Serializer，让前端知道当前用户有哪些专辑
  add_to_serializer(:user, :can_create_collections) do
    scope.user.present?
  end
end
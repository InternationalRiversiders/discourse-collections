# frozen_string_literal: true

# name: discourse-collections
# about: Adds a "Collections" feature similar to Discuz! Tao Album
# version: 0.1
# authors: YourName
# url: https://github.com/yourname/discourse-collections

enabled_site_setting :collections_enabled

register_asset "stylesheets/collections.scss"

module ::DiscourseCollections
  PLUGIN_NAME = "discourse-collections"
end

require_relative "lib/discourse_collections/engine"

Discourse::Application.routes.append { mount ::DiscourseCollections::Engine, at: "/collections" }

after_initialize do
  DiscourseCollections::Engine.routes.draw do
    get "/" => "collections#index"
    post "/" => "collections#create"
    get "/:id" => "collections#show"
    post "/:id/items" => "collections#add_item"
    delete "/:id/items/:item_id" => "collections#remove_item"
    put "/:id/items/:item_id/move" => "collections#move_item"

    # Backward-compatible alias for early local testing.
    post "/:id/add_topic" => "collections#add_item"
  end

  # 让前端能判断当前用户是否可创建专辑
  add_to_serializer(:current_user, :can_create_collections) { object.present? }
end

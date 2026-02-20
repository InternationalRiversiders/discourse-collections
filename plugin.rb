# frozen_string_literal: true

# name: discourse-collections
# about: Adds a "Collections" feature similar to Discuz! Tao Album
# version: 0.1
# authors: Jackzhang144
# url: https://github.com/InternationalRiversiders/discourse-collections

enabled_site_setting :collections_enabled

register_asset "stylesheets/collections.scss"

module ::DiscourseCollections
  PLUGIN_NAME = "discourse-collections"
end

require_relative "lib/discourse_collections/engine"
require_relative "lib/discourse_collections/cache"
require_relative "lib/discourse_collections/meta_tags_builder"

Discourse::Application.routes.append do
  get "/collections" => "list#home", format: false
  get "/collections/mine/:scope" => "list#home", format: false
  get "/collections(.:format)" =>
        "discourse_collections/collections#index",
        constraints: ->(request) { request.format.json? }
  post "/collections(.:format)" =>
         "discourse_collections/collections#create",
         constraints: ->(request) { request.format.json? }
  get "/collections/:id" => "list#home", constraints: { id: /\d+/ }, format: false
  get "/u/:username/collections" => "users#show", constraints: { username: USERNAME_ROUTE_FORMAT }
end

Discourse::Application.routes.append { mount ::DiscourseCollections::Engine, at: "/collections" }

register_html_builder("server:before-head-close") do |controller|
  DiscourseCollections::MetaTagsBuilder.new(controller).html
end

register_html_builder("server:before-head-close-crawler") do |controller|
  DiscourseCollections::MetaTagsBuilder.new(controller).html
end

after_initialize do
  DiscourseCollections::Engine.routes.draw do
    get "/" => "collections#index"
    get "/mine" => "collections#mine"
    get "/user/:username" => "collections#by_user"
    post "/" => "collections#create"
    put "/:id" => "collections#update"
    delete "/:id" => "collections#destroy"
    get "/:id" => "collections#show"
    post "/:id/items" => "collections#add_item"
    delete "/:id/items/:item_id" => "collections#remove_item"
    put "/:id/items/:item_id/move" => "collections#move_item"
    post "/:id/maintainers/invite" => "collections#invite_maintainer"
    post "/:id/maintainers/apply" => "collections#apply_maintainer"
    put "/:id/maintainers/:user_id/approve" => "collections#approve_maintainer"
    put "/:id/maintainers/:user_id/reject" => "collections#reject_maintainer"
    delete "/:id/maintainers/:user_id" => "collections#remove_maintainer"
    put "/:id/owner" => "collections#transfer_ownership"
    put "/:id/recommended" => "collections#set_recommended"
    post "/:id/follow" => "collections#follow"
    delete "/:id/follow" => "collections#unfollow"
    get "/:id/role-events" => "collections#role_events"

    # Backward-compatible alias for early local testing.
    post "/:id/add_topic" => "collections#add_item"
  end

  add_to_serializer(:current_user, :can_create_collections) do
    object.present? && object.trust_level >= SiteSetting.min_trust_level_to_create_collection.to_i
  end
end

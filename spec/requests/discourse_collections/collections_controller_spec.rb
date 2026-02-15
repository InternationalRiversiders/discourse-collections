# frozen_string_literal: true

RSpec.describe DiscourseCollections::CollectionsController do
  fab!(:creator) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:topic_author) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, user: topic_author) }
  fab!(:reply_post) { Fabricate(:post, topic: topic, user: topic_author) }

  before do
    SiteSetting.collections_enabled = true
    SiteSetting.min_trust_level_to_create_collection = TrustLevel[1]
    SiteSetting.max_collections_per_user = 10
  end

  def json_response
    JSON.parse(response.body)
  end

  describe "create + add item flow" do
    it "creates collection and adds topic/reply with notifications" do
      sign_in(creator)

      post "/collections.json", params: { collection: { title: "My Album", description: "desc" } }
      expect(response.status).to eq(200)
      collection_id = json_response.dig("collection", "id")
      expect(collection_id).to be_present

      post "/collections/#{collection_id}/items.json", params: { topic_id: topic.id, note: "great topic" }
      expect(response.status).to eq(200)
      expect(CollectionItem.where(collection_id: collection_id, topic_id: topic.id, post_id: nil).count).to eq(1)

      post "/collections/#{collection_id}/items.json", params: { topic_id: topic.id, note: "dup" }
      expect(response.status).to eq(422)

      post "/collections/#{collection_id}/items.json",
           params: { post_id: reply_post.id, note: "great reply" }
      expect(response.status).to eq(200)
      expect(CollectionItem.where(collection_id: collection_id, post_id: reply_post.id).count).to eq(1)

      expect(
        Notification.where(
          user_id: topic_author.id,
          notification_type: Notification.types[:custom],
        ).count,
      ).to be >= 1
    end
  end

  describe "update flow" do
    it "updates title and description for manager" do
      collection = Collection.create!(creator: creator, owner: creator, title: "Old", description: "old")
      sign_in(creator)

      put "/collections/#{collection.id}.json", params: { collection: { title: "New", description: "new" } }

      expect(response.status).to eq(200)
      expect(collection.reload.title).to eq("New")
      expect(collection.description).to eq("new")
    end
  end

  describe "maintainer flow" do
    it "supports apply + approve" do
      collection = Collection.create!(creator: creator, owner: creator, title: "Maintainers")

      sign_in(other_user)
      post "/collections/#{collection.id}/maintainers/apply.json", params: { note: "let me help" }
      expect(response.status).to eq(200)
      expect(collection.collection_memberships.find_by(user_id: other_user.id).pending?).to eq(true)

      sign_in(creator)
      put "/collections/#{collection.id}/maintainers/#{other_user.id}/approve.json"
      expect(response.status).to eq(200)
      expect(collection.collection_memberships.find_by(user_id: other_user.id).reload.active?).to eq(true)
    end

    it "supports owner invite by username" do
      collection = Collection.create!(creator: creator, owner: creator, title: "Maintainers")

      sign_in(creator)
      post "/collections/#{collection.id}/maintainers/invite.json", params: { username: other_user.username }

      expect(response.status).to eq(200)
      membership = collection.collection_memberships.find_by(user_id: other_user.id)
      expect(membership).to be_present
      expect(membership.active?).to eq(true)
    end
  end

  describe "follow flow" do
    it "supports follow and unfollow" do
      collection = Collection.create!(creator: creator, owner: creator, title: "Followable")

      sign_in(other_user)
      post "/collections/#{collection.id}/follow.json"
      expect(response.status).to eq(200)
      expect(CollectionFollow.where(collection_id: collection.id, user_id: other_user.id).count).to eq(1)

      delete "/collections/#{collection.id}/follow.json"
      expect(response.status).to eq(200)
      expect(CollectionFollow.where(collection_id: collection.id, user_id: other_user.id).count).to eq(0)
    end
  end

  describe "ownership transfer by username" do
    it "transfers owner successfully" do
      collection = Collection.create!(creator: creator, owner: creator, title: "Ownable")

      sign_in(creator)
      put "/collections/#{collection.id}/owner.json", params: { new_owner_username: other_user.username }

      expect(response.status).to eq(200)
      expect(collection.reload.owner_user_id).to eq(other_user.id)
    end
  end

  describe "mine query" do
    it "returns manageable collections without relation incompatibility errors" do
      collection = Collection.create!(creator: creator, owner: creator, title: "Mine")
      collection.collection_memberships.create!(
        user_id: other_user.id,
        status: :active,
        source: :owner_invitation,
        requested_by_user_id: creator.id,
        acted_by_user_id: creator.id,
      )

      sign_in(other_user)
      get "/collections/mine.json"

      expect(response.status).to eq(200)
      ids = json_response.fetch("collections").map { |c| c.fetch("id") }
      expect(ids).to include(collection.id)
    end
  end
end

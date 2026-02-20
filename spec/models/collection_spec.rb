# frozen_string_literal: true

RSpec.describe Collection do
  fab!(:creator) { Fabricate(:user) }
  fab!(:owner) { Fabricate(:user) }
  fab!(:topic_author) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, user: topic_author) }
  fab!(:reply_post) { Fabricate(:post, topic: topic) }

  before { SiteSetting.collections_enabled = true }

  describe "maintainer bootstrap" do
    it "adds creator as active maintainer automatically" do
      collection = Collection.create!(creator: creator, owner: owner, title: "Test Collection")

      membership =
        collection.collection_memberships.find_by(
          user_id: creator.id,
          status: CollectionMembership.statuses[:active],
        )

      expect(membership).to be_present
    end
  end

  describe "#add_post" do
    it "allows collecting replies but rejects first post" do
      collection = Collection.create!(creator: creator, owner: creator, title: "Replies Collection")
      first_post = topic.first_post

      created = collection.add_post(reply_post.id, collected_by_user: creator)
      expect(created).to be_persisted
      expect(created.post_id).to eq(reply_post.id)

      invalid = collection.add_post(first_post.id, collected_by_user: creator)
      expect(invalid).not_to be_valid
      expect(invalid.errors[:post_id]).to be_present
    end
  end

  describe "duplicate protection" do
    it "prevents collecting the same topic twice" do
      collection = Collection.create!(creator: creator, owner: creator, title: "Dup Topic")

      created = collection.add_topic(topic.id, collected_by_user: creator)
      expect(created).to be_persisted

      duplicate = collection.add_topic(topic.id, collected_by_user: creator)
      expect(duplicate).not_to be_persisted
      expect(duplicate.errors[:topic_id]).to be_present
    end
  end

  describe "#transfer_ownership!" do
    it "changes owner and writes role event" do
      collection = Collection.create!(creator: creator, owner: creator, title: "Owner Transfer")

      collection.transfer_ownership!(actor: creator, new_owner: owner)
      collection.reload

      expect(collection.owner_user_id).to eq(owner.id)
      expect(collection.collection_role_events.ownership_transferred.count).to eq(1)
    end
  end

  describe "#soft_delete!" do
    it "sets deleted_at and excludes it from visible scopes" do
      collection = Collection.create!(creator: creator, owner: creator, title: "Soft Delete")

      collection.soft_delete!

      expect(collection.reload.deleted_at).to be_present
      expect(Collection.not_deleted.exists?(collection.id)).to eq(false)
    end
  end
end

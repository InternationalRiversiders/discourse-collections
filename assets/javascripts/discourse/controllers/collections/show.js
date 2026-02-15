import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  applyMaintainer,
  approveMaintainer,
  fetchCollection,
  fetchRoleEvents,
  followCollection,
  inviteMaintainer,
  moveCollectionItem,
  rejectMaintainer,
  removeCollectionItem,
  removeMaintainer,
  transferOwnership,
  unfollowCollection,
  updateCollection,
} from "discourse/plugins/discourse-collections/discourse/lib/collections-api";

export default class CollectionsShowController extends Controller {
  @service dialog;
  @tracked inviteTargets = [];
  @tracked inviteNote = "";
  @tracked newOwnerTargets = [];
  @tracked editingCollection = false;
  @tracked editTitle = "";
  @tracked editDescription = "";

  get collection() {
    return this.model?.collection;
  }

  get roleEvents() {
    return this.model?.roleEvents || [];
  }

  @action
  updateInviteTargets(selected) {
    this.inviteTargets = selected || [];
  }

  @action
  updateInviteNote(valueOrEvent) {
    this.inviteNote = typeof valueOrEvent === "string" ? valueOrEvent : valueOrEvent.target.value;
  }

  @action
  updateNewOwnerTargets(selected) {
    this.newOwnerTargets = selected || [];
  }

  async refreshData() {
    const collectionId = this.collection?.id;
    if (!collectionId) {
      return;
    }

    const [collectionResponse, eventsResponse] = await Promise.all([
      fetchCollection(collectionId),
      fetchRoleEvents(collectionId),
    ]);
    this.model = {
      collection: collectionResponse.collection,
      roleEvents: eventsResponse.role_events || [],
    };
    this.syncEditFields();
  }

  syncEditFields() {
    this.editTitle = this.collection?.title || "";
    this.editDescription = this.collection?.description || "";
  }

  @action
  async follow() {
    try {
      await followCollection(this.collection.id);
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async unfollow() {
    try {
      await unfollowCollection(this.collection.id);
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async applyMaintainer() {
    try {
      await applyMaintainer(this.collection.id);
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async inviteMaintainer() {
    const username = this.inviteTargets?.firstObject || this.inviteTargets?.[0];
    if (!username) {
      return;
    }
    try {
      await inviteMaintainer(this.collection.id, {
        username,
        note: this.inviteNote,
      });
      this.inviteTargets = [];
      this.inviteNote = "";
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async approveApplicant(userId) {
    try {
      await approveMaintainer(this.collection.id, userId);
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async rejectApplicant(userId) {
    try {
      await rejectMaintainer(this.collection.id, userId);
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async removeMaintainer(userId) {
    try {
      await removeMaintainer(this.collection.id, userId);
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async transferOwnership() {
    const newOwnerUsername =
      this.newOwnerTargets?.firstObject || this.newOwnerTargets?.[0];
    if (!newOwnerUsername) {
      return;
    }
    try {
      await transferOwnership(this.collection.id, {
        newOwnerUsername,
      });
      this.newOwnerTargets = [];
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async removeItem(itemId) {
    try {
      await removeCollectionItem(this.collection.id, itemId);
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async moveUp(item) {
    if (item.position <= 0) {
      return;
    }
    try {
      await moveCollectionItem(this.collection.id, item.id, item.position - 1);
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async moveDown(item) {
    const max = (this.collection.items || []).length - 1;
    if (item.position >= max) {
      return;
    }
    try {
      await moveCollectionItem(this.collection.id, item.id, item.position + 1);
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  toggleEditCollection() {
    this.editingCollection = !this.editingCollection;
    if (this.editingCollection) {
      this.syncEditFields();
    }
  }

  @action
  updateEditTitle(event) {
    this.editTitle = typeof event === "string" ? event : event.target.value;
  }

  @action
  updateEditDescription(event) {
    this.editDescription = typeof event === "string" ? event : event.target.value;
  }

  @action
  async saveCollectionEdit() {
    try {
      await updateCollection(this.collection.id, {
        title: this.editTitle.trim(),
        description: this.editDescription.trim(),
      });
      this.editingCollection = false;
      await this.refreshData();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async shareCollection() {
    const shareUrl = `${window.location.origin}/collections/${this.collection.id}`;
    try {
      await navigator.clipboard.writeText(shareUrl);
    } catch (_error) {
      this.dialog.alert(shareUrl);
    }
  }
}

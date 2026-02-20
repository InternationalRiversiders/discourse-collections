import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import {
  createCollection,
  deleteCollection,
  listMyCollections,
  transferOwnership,
} from "discourse/plugins/discourse-collections/discourse/lib/collections-api";

export default class CollectionsMineController extends Controller {
  @service dialog;
  @tracked createTitle = "";
  @tracked createDescription = "";
  @tracked transferTargetsByCollection = {};
  @tracked isCreating = false;
  @tracked activeCollectionActionId = null;

  get collections() {
    return this.model?.collections || [];
  }

  get scope() {
    return this.model?.scope || "owned";
  }

  get isOwnedScope() {
    return this.scope === "owned";
  }

  get title() {
    return this.model?.title || "";
  }

  @action
  updateCreateTitle(valueOrEvent) {
    this.createTitle =
      typeof valueOrEvent === "string" ? valueOrEvent : valueOrEvent.target.value;
  }

  @action
  updateCreateDescription(valueOrEvent) {
    this.createDescription =
      typeof valueOrEvent === "string" ? valueOrEvent : valueOrEvent.target.value;
  }

  @action
  updateTransferTargets(collectionId, selected) {
    this.transferTargetsByCollection = {
      ...this.transferTargetsByCollection,
      [collectionId]: selected || [],
    };
  }

  transferTargetsFor(collectionId) {
    return this.transferTargetsByCollection[collectionId] || [];
  }

  transferUsernameFor(collectionId) {
    return this.transferTargetsFor(collectionId)?.[0];
  }

  async refreshCollections() {
    const response = await listMyCollections({ scope: this.scope });
    this.model = {
      ...this.model,
      collections: response.collections || [],
    };
  }

  @action
  async createOwnedCollection() {
    const title = this.createTitle.trim();
    if (!title) {
      return;
    }

    this.isCreating = true;
    try {
      await createCollection(title, this.createDescription.trim());
      this.createTitle = "";
      this.createDescription = "";
      await this.refreshCollections();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isCreating = false;
    }
  }

  @action
  async transferCollectionOwnership(collectionId) {
    const newOwnerUsername = this.transferUsernameFor(collectionId);
    if (!newOwnerUsername) {
      return;
    }

    this.activeCollectionActionId = collectionId;
    try {
      await transferOwnership(collectionId, { newOwnerUsername });
      const updated = { ...this.transferTargetsByCollection };
      delete updated[collectionId];
      this.transferTargetsByCollection = updated;
      await this.refreshCollections();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.activeCollectionActionId = null;
    }
  }

  @action
  async deleteOwnedCollection(collection) {
    const confirmed = await this.dialog.confirm({
      message: i18n("collections.mine.delete_confirm", { title: collection.title }),
      confirmButtonLabel: "collections.mine.delete_confirm_button",
      cancelButtonLabel: "cancel",
    });

    if (!confirmed) {
      return;
    }

    this.activeCollectionActionId = collection.id;
    try {
      await deleteCollection(collection.id);
      await this.refreshCollections();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.activeCollectionActionId = null;
    }
  }
}

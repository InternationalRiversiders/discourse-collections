import Controller from "@ember/controller";
import { action } from "@ember/object";
import { cancel, debounce } from "@ember/runloop";
import { tracked } from "@glimmer/tracking";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { listCollections } from "discourse/plugins/discourse-collections/discourse/lib/collections-api";

export default class CollectionsIndexController extends Controller {
  @tracked collectionsState = null;
  filter = "latest";
  q = "";
  searchDebounce = null;

  get collections() {
    return this.collectionsState?.collections || this.model?.collections || [];
  }

  @action
  async setFilter(filter) {
    if (this.filter === filter) {
      return;
    }
    this.filter = filter;
    await this.refreshCollections();
  }

  @action
  updateSearch(valueOrEvent) {
    const value =
      typeof valueOrEvent === "string" ? valueOrEvent : valueOrEvent.target.value;
    this.searchDebounce = debounce(this, this.applySearchQuery, value, 350);
  }

  async applySearchQuery(value) {
    if (this.q === value) {
      return;
    }
    this.q = value;
    await this.refreshCollections();
  }

  async refreshCollections() {
    try {
      this.collectionsState = await listCollections({
        filter: this.filter,
        q: this.q,
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.searchDebounce) {
      cancel(this.searchDebounce);
      this.searchDebounce = null;
    }
  }
}

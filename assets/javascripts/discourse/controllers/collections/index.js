import Controller from "@ember/controller";
import { action } from "@ember/object";
import { cancel, debounce } from "@ember/runloop";

export default class CollectionsIndexController extends Controller {
  queryParams = ["filter", "q"];
  filter = "latest";
  q = "";
  searchDebounce = null;

  get collections() {
    return this.model?.collections || [];
  }

  @action
  setFilter(filter) {
    this.filter = filter;
  }

  @action
  updateSearch(valueOrEvent) {
    const value =
      typeof valueOrEvent === "string" ? valueOrEvent : valueOrEvent.target.value;
    this.searchDebounce = debounce(this, this.applySearchQuery, value, 350);
  }

  applySearchQuery(value) {
    this.q = value;
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.searchDebounce) {
      cancel(this.searchDebounce);
      this.searchDebounce = null;
    }
  }
}

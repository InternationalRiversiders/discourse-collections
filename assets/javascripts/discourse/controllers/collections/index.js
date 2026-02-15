import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class CollectionsIndexController extends Controller {
  queryParams = ["filter", "q"];
  filter = "latest";
  q = "";

  get collections() {
    return this.model?.collections || [];
  }

  @action
  setFilter(filter) {
    this.filter = filter;
  }

  @action
  updateSearch(valueOrEvent) {
    this.q = typeof valueOrEvent === "string" ? valueOrEvent : valueOrEvent.target.value;
  }
}

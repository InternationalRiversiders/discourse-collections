import DiscourseRoute from "discourse/routes/discourse";
import { listCollections } from "discourse/plugins/discourse-collections/discourse/lib/collections-api";

export default class CollectionsIndexRoute extends DiscourseRoute {
  async model() {
    return listCollections({ filter: "latest", q: "" });
  }
}

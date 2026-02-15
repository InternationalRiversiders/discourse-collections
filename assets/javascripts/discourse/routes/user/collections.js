import DiscourseRoute from "discourse/routes/discourse";
import { listUserCollections } from "discourse/plugins/discourse-collections/discourse/lib/collections-api";

export default class UserCollectionsRoute extends DiscourseRoute {
  async model() {
    const username = this.modelFor("user").username;
    return listUserCollections(username);
  }
}

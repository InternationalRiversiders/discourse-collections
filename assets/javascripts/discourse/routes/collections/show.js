import DiscourseRoute from "discourse/routes/discourse";
import {
  fetchCollection,
  fetchRoleEvents,
} from "discourse/plugins/discourse-collections/discourse/lib/collections-api";

export default class CollectionsShowRoute extends DiscourseRoute {
  async model(params) {
    const [collectionResponse, eventsResponse] = await Promise.all([
      fetchCollection(params.id),
      fetchRoleEvents(params.id),
    ]);

    return {
      collection: collectionResponse.collection,
      roleEvents: eventsResponse.role_events || [],
    };
  }
}

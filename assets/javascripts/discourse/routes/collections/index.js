import DiscourseRoute from "discourse/routes/discourse";
import { listCollections } from "discourse/plugins/discourse-collections/discourse/lib/collections-api";

export default class CollectionsIndexRoute extends DiscourseRoute {
  queryParams = {
    filter: { refreshModel: true },
    q: { refreshModel: true },
  };

  async model(params) {
    return listCollections({ filter: params.filter, q: params.q });
  }
}

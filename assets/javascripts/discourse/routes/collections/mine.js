import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import { listMyCollections } from "discourse/plugins/discourse-collections/discourse/lib/collections-api";

const SUPPORTED_SCOPES = ["owned", "maintaining", "following"];

function scopeTitle(scope) {
  return i18n(`collections.mine.scopes.${scope}`);
}

export default class CollectionsMineRoute extends DiscourseRoute {
  async model(params) {
    const scope = SUPPORTED_SCOPES.includes(params.scope) ? params.scope : "owned";
    const response = await listMyCollections({ scope });

    return {
      scope,
      title: scopeTitle(scope),
      collections: response.collections || [],
    };
  }
}

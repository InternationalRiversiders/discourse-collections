import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "collections-navigation",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.collections_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.addCommunitySectionLink({
        name: "collections",
        route: "collections.index",
        title: i18n("collections.index_title"),
        text: i18n("collections.nav_title"),
        icon: "folder-tree",
      });

      api.addNavigationBarItem({
        name: "collections",
        displayName: i18n("collections.nav_title"),
        customHref: () => "/collections",
        forceActive: (_category, _args, router) =>
          router.currentRoute?.name?.startsWith("collections"),
      });
    });
  },
};

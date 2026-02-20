import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import CollectReplyButton from "discourse/plugins/discourse-collections/discourse/components/post-menu/collect-reply-button";

export default {
  name: "collections-navigation",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.collections_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.registerValueTransformer(
        "post-menu-buttons",
        ({
          value: dag,
          context: {
            post,
            buttonKeys,
            collapsedButtons,
            lastHiddenButtonKey,
            secondLastHiddenButtonKey,
          },
        }) => {
          if (!post?.id || post.post_number <= 1) {
            return;
          }

          const position = {
            before: lastHiddenButtonKey || buttonKeys.SHOW_MORE,
          };

          if (secondLastHiddenButtonKey) {
            position.after = secondLastHiddenButtonKey;
          }

          dag.add("collectReply", CollectReplyButton, position);
          collapsedButtons.hide("collectReply");
        }
      );

      api.addSidebarSection(
        (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
          const PlazaLink = class extends BaseCustomSidebarSectionLink {
            name = "collections-plaza";
            route = "collections.index";
            title = i18n("collections.sidebar.links.plaza");
            text = i18n("collections.sidebar.links.plaza");
            prefixType = "icon";
            prefixValue = "compass";
          };

          const OwnedLink = class extends BaseCustomSidebarSectionLink {
            name = "collections-owned";
            route = "collections.mine";
            model = "owned";
            title = i18n("collections.sidebar.links.owned");
            text = i18n("collections.sidebar.links.owned");
            prefixType = "icon";
            prefixValue = "crown";
          };

          const MaintainingLink = class extends BaseCustomSidebarSectionLink {
            name = "collections-maintaining";
            route = "collections.mine";
            model = "maintaining";
            title = i18n("collections.sidebar.links.maintaining");
            text = i18n("collections.sidebar.links.maintaining");
            prefixType = "icon";
            prefixValue = "users";
          };

          const FollowingLink = class extends BaseCustomSidebarSectionLink {
            name = "collections-following";
            route = "collections.mine";
            model = "following";
            title = i18n("collections.sidebar.links.following");
            text = i18n("collections.sidebar.links.following");
            prefixType = "icon";
            prefixValue = "heart";
          };

          return class CollectionsSidebarSection extends BaseCustomSidebarSection {
            name = "collections";
            text = i18n("collections.sidebar.title");
            title = i18n("collections.sidebar.title");
            collapsedByDefault = true;

            get displaySection() {
              return Boolean(api.getCurrentUser());
            }

            get links() {
              return [
                new PlazaLink(),
                new OwnedLink(),
                new MaintainingLink(),
                new FollowingLink(),
              ];
            }
          };
        }
      );
    });
  },
};

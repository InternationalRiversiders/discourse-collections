/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { classNames, tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("li")
@classNames("user-main-nav-outlet", "collections")
export default class UserMainNavCollections extends Component {
  static shouldRender(args, { siteSettings }) {
    return siteSettings.collections_enabled && args.model?.id;
  }

  <template>
    <LinkTo @route="user.collections">
      {{icon "folder-tree"}}
      <span>{{i18n "collections.user_tab.nav"}}</span>
    </LinkTo>
  </template>
}

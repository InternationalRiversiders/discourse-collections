import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import AddToCollectionModal from "discourse/plugins/discourse-collections/discourse/components/modal/add-to-collection";

export default class AddReplyToCollection extends Component {
  static shouldRender(args, { currentUser, siteSettings }) {
    return Boolean(
      currentUser &&
        siteSettings.collections_enabled &&
        args.post?.id &&
        args.post?.post_number > 1
    );
  }

  @service modal;

  @action
  openModal() {
    this.modal.show(AddToCollectionModal, {
      model: {
        topicId: this.args.post.topic_id || this.args.post.topicId,
        postId: this.args.post.id,
        postNumber: this.args.post.post_number,
      },
    });
  }

  <template>
    <li class="collections-post-link">
      <DButton
        @class="btn-link add-reply-to-collection"
        @icon="folder-plus"
        @label="collections.collect_reply"
        @action={{this.openModal}}
      />
    </li>
  </template>
}

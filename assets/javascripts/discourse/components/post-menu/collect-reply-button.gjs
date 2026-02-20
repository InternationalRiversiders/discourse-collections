import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import AddToCollectionModal from "discourse/plugins/discourse-collections/discourse/components/modal/add-to-collection";

export default class CollectReplyButton extends Component {
  @service modal;

  static shouldRender(args) {
    return Boolean(args.state.currentUser && args.post?.id && args.post?.post_number > 1);
  }

  get topicId() {
    return this.args.post.topic_id || this.args.post.topic?.id;
  }

  @action
  openModal() {
    if (!this.topicId) {
      return;
    }

    this.modal.show(AddToCollectionModal, {
      model: {
        topicId: this.topicId,
        postId: this.args.post.id,
        postNumber: this.args.post.post_number,
      },
    });
  }

  <template>
    <DButton
      class="post-action-menu__collect-reply collect-reply"
      ...attributes
      @icon="folder-plus"
      @label={{if @showLabel "collections.collect_reply"}}
      @title="collections.collect_reply"
      @action={{this.openModal}}
    />
  </template>
}

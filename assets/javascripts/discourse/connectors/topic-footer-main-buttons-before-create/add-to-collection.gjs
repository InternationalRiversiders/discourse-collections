import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import AddToCollectionModal from "discourse/plugins/discourse-collections/discourse/components/modal/add-to-collection";

export default class AddToCollectionFromTopicFooter extends Component {
  static shouldRender(args, { currentUser, siteSettings }) {
    return Boolean(currentUser && siteSettings.collections_enabled && args.topic?.id);
  }

  @service modal;

  @action
  openModal() {
    this.modal.show(AddToCollectionModal, {
      model: {
        topicId: this.args.topic.id,
        topicTitle: this.args.topic.title,
      },
    });
  }

  <template>
    <DButton
      @class="btn-default topic-footer-button add-to-collection"
      @icon="folder-plus"
      @label="collections.add_to_collection"
      @title="collections.add_to_collection_title"
      @action={{this.openModal}}
    />
  </template>
}

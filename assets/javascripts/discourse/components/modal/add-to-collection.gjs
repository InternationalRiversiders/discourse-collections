import Component from "@glimmer/component";
import { Textarea } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import DModal from "discourse/components/d-modal";
import DButton from "discourse/components/d-button";
import DModalCancel from "discourse/components/d-modal-cancel";
import TextField from "discourse/components/text-field";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  addCollectionItem,
  createCollection,
  listMyCollections,
} from "discourse/plugins/discourse-collections/discourse/lib/collections-api";

export default class AddToCollectionModal extends Component {
  @tracked collections = [];
  @tracked loading = true;
  @tracked selectedCollectionId = null;
  @tracked searchQuery = "";
  @tracked note = "";
  @tracked quickCreateTitle = "";
  @tracked saving = false;

  constructor() {
    super(...arguments);
    this.refreshCollections();
  }

  get targetLabel() {
    if (this.args.model.postId) {
      return this.args.model.postNumber
        ? `#${this.args.model.postNumber}`
        : `#${this.args.model.postId}`;
    }
    return this.args.model.topicTitle || `#${this.args.model.topicId}`;
  }

  get canSubmit() {
    const selected = this.collections.find((c) => c.id === this.selectedCollectionId);
    return Boolean(selected && !selected.already_contains) && !this.saving;
  }

  get canCreateQuick() {
    return this.quickCreateTitle.trim().length > 0 && !this.saving;
  }

  @action
  async refreshCollections() {
    this.loading = true;
    try {
      const response = await listMyCollections({
        q: this.searchQuery.trim(),
        containsTopicId: this.args.model.topicId,
        containsPostId: this.args.model.postId,
      });
      this.collections = response.collections || [];
      if (
        this.selectedCollectionId &&
        !this.collections.find((c) => c.id === this.selectedCollectionId)
      ) {
        this.selectedCollectionId = null;
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  updateSearch(valueOrEvent) {
    this.searchQuery = typeof valueOrEvent === "string" ? valueOrEvent : valueOrEvent.target.value;
  }

  @action
  updateQuickCreateTitle(valueOrEvent) {
    this.quickCreateTitle =
      typeof valueOrEvent === "string" ? valueOrEvent : valueOrEvent.target.value;
  }

  @action
  updateNote(valueOrEvent) {
    this.note = typeof valueOrEvent === "string" ? valueOrEvent : valueOrEvent.target.value;
  }

  @action
  selectCollection(collectionId) {
    this.selectedCollectionId = collectionId;
  }

  @action
  async createQuickCollection() {
    if (!this.canCreateQuick) {
      return;
    }

    this.saving = true;
    try {
      const response = await createCollection(this.quickCreateTitle.trim());
      const created = response.collection;
      this.quickCreateTitle = "";
      await this.refreshCollections();
      if (created?.id) {
        this.selectedCollectionId = created.id;
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  async submit() {
    if (!this.canSubmit) {
      return;
    }

    this.saving = true;
    try {
      await addCollectionItem(this.selectedCollectionId, {
        topicId: this.args.model.topicId,
        postId: this.args.model.postId,
        note: this.note.trim(),
      });
      this.args.closeModal?.();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "collections.modal.title"}}
      @subtitle={{i18n
        "collections.modal.subtitle"
        target=this.targetLabel
      }}
      @bodyClass="collections-add-modal"
      class="collections-add-modal"
    >
      <div class="collections-add-modal__layout">
        <section class="collections-add-modal__section">
          <h4>{{i18n "collections.modal.select_existing"}}</h4>

          <div class="collections-add-modal__search">
            <TextField
              @value={{this.searchQuery}}
              @onChangeImmediate={{this.updateSearch}}
              @placeholder={{i18n "collections.modal.search_placeholder"}}
              class="collections-input"
            />
            <DButton
              @label="collections.modal.search"
              @action={{this.refreshCollections}}
              @disabled={{this.loading}}
              class="btn-default"
            />
          </div>

          {{#if this.loading}}
            <p class="collections-add-modal__hint">
              {{i18n "collections.modal.loading"}}
            </p>
          {{else}}
            <ul class="collections-add-modal__list">
              {{#each this.collections as |collection|}}
                <li>
                  <button
                    type="button"
                    disabled={{collection.already_contains}}
                    class={{if
                      (eq this.selectedCollectionId collection.id)
                      "is-selected"
                    }}
                    {{on "click" (fn this.selectCollection collection.id)}}
                  >
                    <span class="collections-add-modal__list-title">
                      {{collection.title}}
                    </span>
                    <span class="collections-add-modal__list-meta">
                      {{#if collection.already_contains}}
                        {{i18n "collections.modal.already_added"}}
                      {{else}}
                        {{i18n
                          "collections.card.items_count"
                          count=collection.items_count
                        }}
                      {{/if}}
                    </span>
                  </button>
                </li>
              {{else}}
                <li class="collections-add-modal__hint">
                  {{i18n "collections.modal.empty"}}
                </li>
              {{/each}}
            </ul>
          {{/if}}
        </section>

        <section class="collections-add-modal__section">
          <h4>{{i18n "collections.modal.quick_create"}}</h4>
          <div class="collections-add-modal__quick-create">
            <TextField
              @value={{this.quickCreateTitle}}
              @onChangeImmediate={{this.updateQuickCreateTitle}}
              @placeholder={{i18n "collections.modal.quick_create_placeholder"}}
              class="collections-input"
            />
            <DButton
              @label="collections.modal.create"
              @action={{this.createQuickCollection}}
              @disabled={{not this.canCreateQuick}}
              class="btn-primary"
            />
          </div>

          <label>{{i18n "collections.modal.note_label"}}</label>
          <Textarea
            @value={{this.note}}
            @placeholder={{i18n "collections.modal.note_placeholder"}}
            @rows="5"
            class="collections-textarea"
            {{on "input" this.updateNote}}
          />
        </section>
      </div>

      <div class="collections-add-modal__actions">
        <DModalCancel @close={{@closeModal}} />
        <DButton
          @label="collections.modal.confirm_add"
          @action={{this.submit}}
          @disabled={{not this.canSubmit}}
          class="btn-primary"
        />
      </div>
    </DModal>
  </template>
}

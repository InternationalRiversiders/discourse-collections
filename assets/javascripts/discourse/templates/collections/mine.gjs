import { fn, get, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import UserAvatar from "discourse/components/user-avatar";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default <template>
  <section class="collections-plaza user-content" id="user-content">
    <header class="collections-plaza__header">
      <div>
        <h1>{{@controller.title}}</h1>
      </div>
    </header>

    {{#if @controller.isOwnedScope}}
      <section class="collections-mine__create">
        <TextField
          @value={{@controller.createTitle}}
          @onChangeImmediate={{@controller.updateCreateTitle}}
          @placeholder={{i18n "collections.mine.create_title_placeholder"}}
          class="collections-input"
        />
        <TextField
          @value={{@controller.createDescription}}
          @onChangeImmediate={{@controller.updateCreateDescription}}
          @placeholder={{i18n "collections.mine.create_description_placeholder"}}
          class="collections-input"
        />
        <DButton
          @label="collections.mine.create_button"
          @action={{@controller.createOwnedCollection}}
          @disabled={{@controller.isCreating}}
          class="btn-primary"
        />
      </section>
    {{/if}}

    <table class="topic-list collections-topic-list">
      <thead class="topic-list-header">
        <tr>
          <th class="topic-list-data">{{i18n "collections.columns.collection"}}</th>
          <th class="topic-list-data num">{{i18n "collections.columns.items"}}</th>
          <th class="topic-list-data num">{{i18n "collections.columns.followers"}}</th>
          {{#if @controller.isOwnedScope}}
            <th class="topic-list-data">{{i18n "collections.columns.actions"}}</th>
          {{/if}}
        </tr>
      </thead>
      <tbody class="topic-list-body">
        {{#each @controller.collections as |collection|}}
          <tr class="topic-list-item">
            <td class="main-link topic-list-data">
              <div class="collections-row-main">
                <UserAvatar
                  @user={{hash
                    username=collection.creator_username
                    avatar_template=collection.creator_avatar_template
                  }}
                  @size="large"
                />
                <div class="collections-row-main__content">
                  <LinkTo
                    @route="collections.show"
                    @model={{collection.id}}
                    class="title raw-link raw-topic-link"
                  >
                    {{collection.title}}
                  </LinkTo>
                  {{#if collection.description}}
                    <div class="topic-excerpt">{{collection.description}}</div>
                  {{/if}}
                  <div class="collections-row-main__meta">
                    {{i18n "collections.card.by_user" username=collection.creator_username}}
                  </div>
                </div>
              </div>
            </td>
            <td class="num topic-list-data">{{collection.items_count}}</td>
            <td class="num topic-list-data">{{collection.followers_count}}</td>
            {{#if @controller.isOwnedScope}}
              <td class="topic-list-data">
                <div class="collections-mine__actions">
                  <EmailGroupUserChooser
                    @value={{get @controller.transferTargetsByCollection collection.id}}
                    @onChange={{fn @controller.updateTransferTargets collection.id}}
                    @options={{hash
                      maximum=1
                      excludeCurrentUser=true
                      filterPlaceholder="collections.mine.transfer_placeholder"
                    }}
                    class="collections-mine__transfer-chooser"
                  />
                  <DButton
                    @label="collections.mine.transfer_button"
                    @action={{fn @controller.transferCollectionOwnership collection.id}}
                    @disabled={{eq @controller.activeCollectionActionId collection.id}}
                    class="btn-default btn-small"
                  />
                  <DButton
                    @label="collections.mine.delete_button"
                    @action={{fn @controller.deleteOwnedCollection collection}}
                    @disabled={{eq @controller.activeCollectionActionId collection.id}}
                    class="btn-danger btn-small"
                  />
                </div>
              </td>
            {{/if}}
          </tr>
        {{else}}
          <tr>
            <td class="topic-list-data" colspan={{if @controller.isOwnedScope "4" "3"}}>
              <div class="collections-empty">{{i18n "collections.mine.empty"}}</div>
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </section>
</template>;

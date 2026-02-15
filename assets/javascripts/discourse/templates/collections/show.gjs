import { Textarea } from "@ember/component";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import RelativeDate from "discourse/components/relative-date";
import TextField from "discourse/components/text-field";
import UserAvatar from "discourse/components/user-avatar";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { i18n } from "discourse-i18n";

export default <template>
  <section class="collection-detail user-content" id="user-content">
    <header class="collection-detail__header">
      <div class="collection-detail__identity">
        <UserAvatar
          @user={{hash
            username=@controller.collection.creator_username
            avatar_template=@controller.collection.creator_avatar_template
          }}
          @size="large"
        />
        <div>
          <h1>{{@controller.collection.title}}</h1>
          <p>{{@controller.collection.description}}</p>
          <div class="collection-detail__meta">
            <span>
              {{i18n
                "collections.detail.creator"
                username=@controller.collection.creator_username
              }}
            </span>
            <span>
              {{i18n
                "collections.detail.owner"
                username=@controller.collection.owner_username
              }}
            </span>
            <span>
              {{i18n
                "collections.card.followers_count"
                count=@controller.collection.followers_count
              }}
            </span>
          </div>
        </div>
      </div>

      <div class="collection-detail__actions">
        {{#if @controller.collection.current_user_can_invite}}
          <DButton
            @label="collections.detail.edit"
            @action={{@controller.toggleEditCollection}}
            class="btn-default"
          />
        {{/if}}
        <DButton
          @label="collections.detail.share"
          @action={{@controller.shareCollection}}
          class="btn-default"
        />
        {{#if @controller.collection.followed_by_current_user}}
          <DButton
            @label="collections.detail.unfollow"
            @action={{@controller.unfollow}}
            class="btn-default"
          />
        {{else}}
          <DButton
            @label="collections.detail.follow"
            @action={{@controller.follow}}
            class="btn-primary"
          />
        {{/if}}
        {{#if @controller.collection.current_user_can_apply_maintainer}}
          <DButton
            @label="collections.detail.apply_maintainer"
            @action={{@controller.applyMaintainer}}
            class="btn-default"
          />
        {{/if}}
      </div>
    </header>

    {{#if @controller.editingCollection}}
      <section class="collection-detail__editor form-vertical">
        <h3>{{i18n "collections.detail.edit"}}</h3>
        <div class="control-group">
          <label class="control-label">{{i18n "collections.detail.edit_title_placeholder"}}</label>
          <TextField
            @value={{@controller.editTitle}}
            @onChangeImmediate={{@controller.updateEditTitle}}
            @placeholder={{i18n "collections.detail.edit_title_placeholder"}}
            class="input-xxlarge"
          />
        </div>
        <div class="control-group">
          <label class="control-label">{{i18n "collections.detail.edit_description_placeholder"}}</label>
          <Textarea
            @value={{@controller.editDescription}}
            @placeholder={{i18n "collections.detail.edit_description_placeholder"}}
            @rows="4"
            class="collection-textarea"
            {{on "input" @controller.updateEditDescription}}
          />
        </div>
        <div class="collection-detail__editor-actions">
          <DButton
            @label="cancel"
            @action={{@controller.toggleEditCollection}}
            class="btn-default"
          />
          <DButton
            @label="collections.detail.save"
            @action={{@controller.saveCollectionEdit}}
            class="btn-primary"
          />
        </div>
      </section>
    {{/if}}

    <div class="collection-detail__body">
      <section class="collection-detail__items">
        <h2>{{i18n "collections.detail.items"}}</h2>

        <table class="topic-list collections-topic-list">
          <thead class="topic-list-header">
            <tr>
              <th class="topic-list-data">{{i18n "collections.columns.collection"}}</th>
              {{#if @controller.collection.current_user_is_maintainer}}
                <th class="topic-list-data num">{{i18n "collections.columns.actions"}}</th>
              {{/if}}
            </tr>
          </thead>
          <tbody class="topic-list-body">
            {{#each @controller.collection.items as |item|}}
              <tr class="topic-list-item">
                <td class="main-link topic-list-data">
                  <a
                    class="title raw-link raw-topic-link"
                    href={{if
                      item.post.post_number
                      (concat "/t/" item.topic.slug "/" item.topic.id "/" item.post.post_number)
                      (concat "/t/" item.topic.slug "/" item.topic.id)
                    }}
                  >
                    {{item.topic.title}}
                  </a>
                  {{#if item.post_id}}
                    <div class="collections-row-main__meta">
                      {{i18n "collections.detail.reply_ref" post_id=item.post_id}}
                    </div>
                  {{/if}}
                  {{#if item.note}}
                    <div class="topic-excerpt">{{item.note}}</div>
                  {{/if}}
                </td>
                {{#if @controller.collection.current_user_is_maintainer}}
                  <td class="num topic-list-data">
                    <div class="collection-item-row__buttons">
                      <DButton
                        @icon="arrow-up"
                        @action={{fn @controller.moveUp item}}
                        class="btn-default btn-small"
                      />
                      <DButton
                        @icon="arrow-down"
                        @action={{fn @controller.moveDown item}}
                        class="btn-default btn-small"
                      />
                      <DButton
                        @icon="trash-can"
                        @action={{fn @controller.removeItem item.id}}
                        class="btn-danger btn-small"
                      />
                    </div>
                  </td>
                {{/if}}
              </tr>
            {{else}}
              <tr>
                <td class="topic-list-data" colspan="2">
                  <div class="collections-empty">{{i18n "collections.detail.empty_items"}}</div>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </section>

      <aside class="collection-detail__side">
        <section>
          <h3>{{i18n "collections.detail.maintainers"}}</h3>
          <ul class="collection-detail__maintainers">
            {{#each @controller.collection.maintainers as |maintainer|}}
              <li>
                <UserAvatar
                  @user={{hash
                    username=maintainer.username
                    avatar_template=maintainer.user_avatar_template
                  }}
                  @size="small"
                />
                <span>{{maintainer.username}}</span>
                {{#if @controller.collection.current_user_can_manage}}
                  <DButton
                    @icon="xmark"
                    @action={{fn @controller.removeMaintainer maintainer.user_id}}
                    class="btn-small btn-default"
                  />
                {{/if}}
              </li>
            {{/each}}
          </ul>
        </section>

        {{#if @controller.collection.current_user_can_invite}}
          <section class="collection-detail__manager-panel form-vertical">
            <h3>{{i18n "collections.detail.invite_maintainer"}}</h3>
            <div class="control-group">
              <EmailGroupUserChooser
                @value={{@controller.inviteTargets}}
                @onChange={{@controller.updateInviteTargets}}
                @options={{hash
                  maximum=1
                  excludeCurrentUser=true
                  filterPlaceholder="collections.detail.username_placeholder"
                }}
                class="input-xxlarge"
              />
            </div>
            <div class="control-group">
              <Textarea
                @value={{@controller.inviteNote}}
                @placeholder={{i18n "collections.detail.invite_note_placeholder"}}
                @rows="3"
                class="collection-textarea"
                {{on "input" @controller.updateInviteNote}}
              />
            </div>
            <DButton
              @label="collections.detail.invite"
              @action={{@controller.inviteMaintainer}}
              class="btn-primary"
            />

            {{#if @controller.collection.current_user_can_manage}}
              <h3>{{i18n "collections.detail.pending_applications"}}</h3>
              <ul class="collection-detail__pending-list">
                {{#each @controller.collection.pending_applications as |pending|}}
                  <li>
                    <span>{{pending.username}}</span>
                    <div>
                      <DButton
                        @label="collections.detail.approve"
                        @action={{fn @controller.approveApplicant pending.user_id}}
                        class="btn-small btn-primary"
                      />
                      <DButton
                        @label="collections.detail.reject"
                        @action={{fn @controller.rejectApplicant pending.user_id}}
                        class="btn-small btn-default"
                      />
                    </div>
                  </li>
                {{else}}
                  <li class="collections-empty">
                    {{i18n "collections.detail.no_pending"}}
                  </li>
                {{/each}}
              </ul>

              <h3>{{i18n "collections.detail.transfer_owner"}}</h3>
              <div class="control-group">
                <EmailGroupUserChooser
                  @value={{@controller.newOwnerTargets}}
                  @onChange={{@controller.updateNewOwnerTargets}}
                  @options={{hash
                    maximum=1
                    excludeCurrentUser=true
                    filterPlaceholder="collections.detail.new_owner_placeholder"
                  }}
                  class="input-xxlarge"
                />
              </div>
              <DButton
                @label="collections.detail.transfer"
                @action={{@controller.transferOwnership}}
                class="btn-danger"
              />
            {{/if}}
          </section>
        {{/if}}
      </aside>
    </div>

    <section class="collection-detail__events">
      <h3>{{i18n "collections.detail.role_events"}}</h3>
      <ul>
        {{#each @controller.roleEvents as |event|}}
          <li>
            <span>{{event.event_type}}</span>
            <span>{{event.actor_username}}</span>
            <span><RelativeDate @date={{event.created_at}} /></span>
          </li>
        {{else}}
          <li class="collections-empty">{{i18n "collections.detail.no_events"}}</li>
        {{/each}}
      </ul>
    </section>
  </section>
</template>;

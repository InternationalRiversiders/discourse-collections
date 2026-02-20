import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import UserAvatar from "discourse/components/user-avatar";
import { i18n } from "discourse-i18n";

export default <template>
  <section class="collections-plaza user-content" id="user-content">
    <header class="collections-plaza__header">
      <div>
        <h1>{{@controller.title}}</h1>
      </div>
    </header>

    <table class="topic-list collections-topic-list">
      <thead class="topic-list-header">
        <tr>
          <th class="topic-list-data">{{i18n "collections.columns.collection"}}</th>
          <th class="topic-list-data num">{{i18n "collections.columns.items"}}</th>
          <th class="topic-list-data num">{{i18n "collections.columns.followers"}}</th>
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
          </tr>
        {{else}}
          <tr>
            <td class="topic-list-data" colspan="3">
              <div class="collections-empty">{{i18n "collections.mine.empty"}}</div>
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </section>
</template>;

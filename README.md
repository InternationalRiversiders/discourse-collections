# discourse-collections（淘专辑）

`discourse-collections` 是一个面向 Discourse 社区的「公共收藏夹 / 精选集」插件。  
目标是把社区中的高质量主题与回复沉淀成可发现、可关注、可协作维护的“淘专辑”。

## 插件定位

- 仅提供“公共淘专辑”，不支持私有收藏夹
- 收录对象支持 `Topic`（主题）与 `Post`（回复）
- 专辑列表展示创建者头像，不使用 `background_url`

## 核心功能

### 1. 内容收录
- 在主题页与回复位置提供“加入专辑”入口
- 收录项支持推荐语 `note`
- 支持排序移动（上移/下移）
- 防止同一专辑重复收录同一主题/回复

### 2. 角色与协作
- 角色区分：创建者（Creator）、拥有者（Owner）、维护者（Maintainer）
- 初始创建时：创建者 = 拥有者，且创建者默认是维护者
- 拥有者权限：邀请维护者、移除维护者、审批/拒绝自荐、转交所有权
- 维护者可通过邀请加入，也可“毛遂自荐”并由拥有者审批
- 角色变化会写入专门的审计记录（role events）

### 3. 发现与流量
- 专辑广场：`/collections`
- 专辑详情：`/collections/:id`
- 用户专辑：`/u/:username/collections`
- 支持关注/取消关注
- 支持 staff 推荐标记

### 4. 通知与分享
- 内容被收录时，通知原作者
- 专辑详情页输出 Open Graph / Twitter Meta 标签，优化外部分享预览

### 5. 后台可配置项
- `collections_enabled`
- `min_trust_level_to_create_collection`
- `max_collections_per_user`

## 数据结构

当前插件会创建以下核心表：

- `collections`
- `collection_items`
- `collection_memberships`
- `collection_role_events`
- `collection_follows`

说明：

- `collections` 包含 `created_at` / `updated_at`
- `collection_items` 包含 `collected_at`（收录时间）
- 维护者与拥有者的演进通过 `collection_memberships` + `collection_role_events` 记录

## API 概览

- `GET /collections.json`
- `GET /collections/mine.json`
- `GET /collections/user/:username.json`
- `POST /collections.json`
- `PUT /collections/:id.json`
- `GET /collections/:id.json`
- `POST /collections/:id/items.json`
- `DELETE /collections/:id/items/:item_id.json`
- `PUT /collections/:id/items/:item_id/move.json`
- `POST /collections/:id/maintainers/invite.json`
- `POST /collections/:id/maintainers/apply.json`
- `PUT /collections/:id/maintainers/:user_id/approve.json`
- `PUT /collections/:id/maintainers/:user_id/reject.json`
- `DELETE /collections/:id/maintainers/:user_id.json`
- `PUT /collections/:id/owner.json`
- `GET /collections/:id/role-events.json`
- `POST /collections/:id/follow.json`
- `DELETE /collections/:id/follow.json`
- `PUT /collections/:id/recommended.json`

## 安装（WSL / 开发环境）

假设你当前在 Discourse 源码根目录（例如 `~/discourse`），并且插件目录在：
`/Users/jackzhang/Code/IdeaProjects/discourse-collections`

### 1. 放置插件

```bash
cd ~/discourse
ln -s /Users/jackzhang/Code/IdeaProjects/discourse-collections plugins/discourse-collections
```

如果不想用软链接，也可以直接复制到 `plugins/discourse-collections`。

### 2. 执行迁移

```bash
RAILS_ENV=development bundle exec rake db:migrate
```

### 3. 启动与前端编译

```bash
bin/rails server
```

另开一个终端（可选）：

```bash
d/ember-cli
```

### 4. 后台启用

进入 `Admin -> Settings`，开启：

- `collections_enabled`

按需设置：

- `min_trust_level_to_create_collection`
- `max_collections_per_user`

## 性能优化（Redis 缓存）

本插件已接入 Discourse 的 `Discourse.cache`（默认 Redis）来降低高频查询压力。

### 已缓存接口

- `GET /collections`（广场）
- `GET /collections/mine`
- `GET /collections/user/:username`
- `GET /collections/:id`（详情）
- `GET /collections/:id/role-events`
- 专辑详情页 Meta 标签构建

### 缓存策略

- 使用“全局版本 + 单专辑版本”键策略进行精确失效
- 写操作后统一 bump 版本（新增/编辑/收录/排序/关注/角色变更/转移所有权等）
- 用户态字段采用 overlay 计算，避免共享缓存串用户状态
- 广场搜索输入采用防抖，减少前端频繁请求

## 快速验证清单

1. 打开 `/collections`，切换筛选并搜索，确认页面响应流畅
2. 打开 `/collections/:id`，确认收录列表、维护者、角色日志正常显示
3. 执行“添加收录/关注/维护者审批”等写操作后刷新，确认数据立即更新
4. 在用户页 `/u/:username/collections` 确认专辑列表展示正常

## 目录结构（关键）

- `plugin.rb`
- `config/settings.yml`
- `db/migrate/20260215090000_create_collections_tables.rb`
- `app/models/*`
- `app/controllers/discourse_collections/collections_controller.rb`
- `lib/discourse_collections/cache.rb`
- `lib/discourse_collections/meta_tags_builder.rb`
- `assets/javascripts/discourse/*`
- `assets/stylesheets/collections.scss`

## 已知说明

- 这是 Discourse 插件工程，需放在 Discourse 插件目录下运行
- 若本地缺少测试依赖，`bundle exec rspec` 可能无法执行，请先 `bundle install`

# discourse-collections（淘专辑）

`discourse-collections` 是一个面向 Discourse 社区的「公共收藏夹/精选集」插件。  
它让用户可以把优质内容沉淀为可发现、可关注、可协作维护的专辑，提升社区内容分发效率。

## 插件介绍

这个插件聚焦「公共淘专辑」，不提供私有收藏夹。核心体验包括：

- 在帖子页一键收录内容到专辑（支持主题和回复）
- 专辑广场浏览与筛选（最新、最多关注、推荐）
- 专辑详情页查看收录条目、推荐语、维护者与角色变更记录
- 用户主页中展示该用户创建的公开专辑
- 关注专辑与通知激励（内容被收录时通知作者）

## 功能概览

### 1. 内容收录
- 支持收录 `Topic`（主题）和 `Post`（回复）
- 每条收录项支持推荐语（`note`）
- 支持收录项排序移动
- 防止重复收录同一目标

### 2. 角色与协作
- 角色分为：创建者（Creator）、拥有者（Owner）、维护者（Maintainer）
- 创建者默认也是维护者
- 维护者可由创建者/拥有者邀请，也可用户自荐后由拥有者审批
- 支持拥有者转移
- 维护者/拥有者变化写入审计日志（role events）

### 3. 发现与流量
- 专辑广场页：`/collections`
- 专辑详情页：`/collections/:id`
- 用户专辑页：`/u/:username/collections`
- 支持关注/取消关注专辑
- 支持专辑推荐标记（staff）

### 4. SEO 与分享
- 专辑详情页生成基础 Open Graph / Twitter meta
- 分享时可获得更友好的链接预览

### 5. 后台限制
- `min_trust_level_to_create_collection`
- `max_collections_per_user`
- `collections_enabled`

## 主要 API

- `GET /collections.json`
- `GET /collections/mine.json`
- `GET /collections/user/:username.json`
- `POST /collections.json`
- `PUT /collections/:id.json`
- `GET /collections/:id.json`
- `POST /collections/:id/items.json`
- `DELETE /collections/:id/items/:item_id.json`
- `PUT /collections/:id/items/:item_id/move.json`
- `POST /collections/:id/maintainers/invite.json`（支持 `user_id` 或 `username`）
- `POST /collections/:id/maintainers/apply.json`
- `PUT /collections/:id/maintainers/:user_id/approve.json`
- `PUT /collections/:id/maintainers/:user_id/reject.json`
- `DELETE /collections/:id/maintainers/:user_id.json`
- `PUT /collections/:id/owner.json`（支持 `new_owner_user_id` 或 `new_owner_username`）
- `GET /collections/:id/role-events.json`
- `POST /collections/:id/follow.json`
- `DELETE /collections/:id/follow.json`

## 安装方式（开发/测试）

1. 将插件目录放入 Discourse 的 `plugins/` 下（目录名建议为 `discourse-collections`）。
2. 在 Discourse 根目录执行数据库迁移：

```bash
RAILS_ENV=development bundle exec rake db:migrate
```

3. 进入后台 `Admin -> Settings`，启用：
- `collections_enabled`

4. 按需配置：
- `min_trust_level_to_create_collection`
- `max_collections_per_user`

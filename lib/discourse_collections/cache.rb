# frozen_string_literal: true

require "digest/sha1"

module DiscourseCollections
  module Cache
    GLOBAL_VERSION_KEY = "collections:global_version"
    COLLECTION_VERSION_KEY_PREFIX = "collections:collection_version"
    VERSION_TTL = 30.days

    module_function

    def plaza_key(filter:, q:, limit:)
      join(
        "collections",
        "plaza",
        "v#{global_version}",
        "f#{filter}",
        "q#{digest(q)}",
        "l#{limit}",
      )
    end

    def mine_key(user_id:, scope:, q:, limit:, contains_topic_id:, contains_post_id:)
      join(
        "collections",
        "mine",
        "v#{global_version}",
        "u#{user_id}",
        "s#{scope}",
        "q#{digest(q)}",
        "l#{limit}",
        "t#{contains_topic_id || 0}",
        "p#{contains_post_id || 0}",
      )
    end

    def by_user_key(user_id:, q:, limit:)
      join(
        "collections",
        "by_user",
        "v#{global_version}",
        "u#{user_id}",
        "q#{digest(q)}",
        "l#{limit}",
      )
    end

    def show_key(collection_id:)
      join(
        "collections",
        "show",
        "c#{collection_id}",
        "v#{collection_version(collection_id)}",
      )
    end

    def role_events_key(collection_id:, limit:)
      join(
        "collections",
        "role_events",
        "c#{collection_id}",
        "v#{collection_version(collection_id)}",
        "l#{limit}",
      )
    end

    def meta_tags_key(collection_id:)
      join(
        "collections",
        "meta_tags",
        "c#{collection_id}",
        "v#{collection_version(collection_id)}",
      )
    end

    def touch_collection!(collection_id)
      bump!(GLOBAL_VERSION_KEY)
      bump!(collection_version_key(collection_id))
    end

    def global_version
      Discourse.cache.read(GLOBAL_VERSION_KEY).to_i
    end

    def collection_version(collection_id)
      Discourse.cache.read(collection_version_key(collection_id)).to_i
    end

    def digest(value)
      return "blank" if value.blank?
      Digest::SHA1.hexdigest(value.to_s)
    end

    def bump!(key)
      if Discourse.cache.respond_to?(:redis) && Discourse.cache.respond_to?(:normalize_key)
        normalized_key = Discourse.cache.normalize_key(key)
        Discourse.cache.redis.incr(normalized_key)
        Discourse.cache.redis.expire(normalized_key, VERSION_TTL.to_i)
      else
        current_version = Discourse.cache.read(key).to_i
        Discourse.cache.write(key, current_version + 1, expires_in: VERSION_TTL)
      end
    end
    private_class_method :bump!

    def collection_version_key(collection_id)
      "#{COLLECTION_VERSION_KEY_PREFIX}:#{collection_id}"
    end
    private_class_method :collection_version_key

    def join(*parts)
      parts.join(":")
    end
    private_class_method :join
  end
end

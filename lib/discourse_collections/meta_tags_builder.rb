# frozen_string_literal: true

require "erb"

module DiscourseCollections
  class MetaTagsBuilder
    attr_reader :controller

    def initialize(controller)
      @controller = controller
    end

    def html
      return "" if !SiteSetting.collections_enabled

      collection_id = extract_collection_id(controller.request&.path)
      return "" if collection_id.blank?

      collection = Collection.includes(:creator).find_by(id: collection_id)
      return "" if collection.blank?

      avatar_template = collection.creator&.avatar_template
      avatar_url = avatar_template.present? ? avatar_template.gsub("{size}", "240") : nil
      absolute_avatar_url =
        if avatar_url.present? && avatar_url.start_with?("/")
          "#{Discourse.base_url_no_prefix}#{avatar_url}"
        else
          avatar_url
        end

      title = "淘专辑：#{collection.title}"
      description = collection.description.presence || "发现来自社区的精选主题与回复收藏。"

      tags = []
      tags << %(<meta property="og:title" content="#{escape(title)}">)
      tags << %(<meta property="og:description" content="#{escape(description.truncate(200))}">)
      tags << %(<meta property="og:type" content="website">)
      tags << %(<meta property="og:image" content="#{escape(absolute_avatar_url)}">) if absolute_avatar_url.present?
      tags << %(<meta name="twitter:card" content="summary_large_image">)
      tags << %(<meta name="twitter:title" content="#{escape(title)}">)
      tags << %(<meta name="twitter:description" content="#{escape(description.truncate(200))}">)
      tags.join("\n")
    end

    private

    def extract_collection_id(path)
      return nil if path.blank?
      match = path.match(%r{\A/collections/(\d+)(?:$|[/?#])})
      match&.captures&.first
    end

    def escape(value)
      ERB::Util.html_escape(value.to_s)
    end
  end
end

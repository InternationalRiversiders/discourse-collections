# frozen_string_literal: true

module ::DiscourseCollections
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseCollections
  end
end

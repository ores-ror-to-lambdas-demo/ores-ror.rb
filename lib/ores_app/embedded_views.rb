# frozen_string_literal: true

require "action_view/testing/resolvers"

module OresApp
  module EmbeddedViews
    module_function

    def resolver
      @resolver ||= ActionView::FixtureResolver.new({})
    end

    def add(templates)
      resolver.data.merge!(templates)
      resolver.clear_cache
      resolver
    end
  end
end

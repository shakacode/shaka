# frozen_string_literal: true

module ShakaDocs
  # One traversal identifies every document reference and external navigation URL.
  module Navigation
    module_function

    def items(item)
      case item
      when String then [[:doc, item]]
      when Array then item.flat_map { |child| items(child) }
      when Hash then typed_items(item)
      else raise ArgumentError, "Unsupported sidebar item: #{item.inspect}"
      end
    end

    def typed_items(item)
      case item['type']
      when 'doc' then [target(item, 'id', :doc)]
      when 'link' then [target(item, 'href', :url)]
      when 'category' then items(item.fetch('items')) + landing_items(item['link'])
      else raise ArgumentError, "Unsupported sidebar item: #{item.inspect}"
      end
    end

    def landing_items(item)
      return [] if item.nil?
      raise ArgumentError, 'Expected a category link object' unless item.is_a?(Hash)
      return [] if item['type'] == 'generated-index'
      raise ArgumentError, "Unsupported category link: #{item.inspect}" unless item['type'] == 'doc'

      [target(item, 'id', :doc)]
    end

    def target(item, key, kind)
      value = item.fetch(key)
      raise ArgumentError, "Expected a string sidebar #{key}" unless value.is_a?(String)

      [kind, value]
    end
  end
end

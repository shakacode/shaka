# frozen_string_literal: true

module ShakaDocs
  # One traversal identifies every document reference and external navigation URL.
  module Navigation
    module_function

    def items(collection)
      raise ArgumentError, 'Expected sidebar items array' unless collection.is_a?(Array)

      collection.flat_map { |item| node(item) }
    end

    def node(item)
      case item
      when String then [[:doc, item]]
      when Array then items(item)
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

    # A page filed under docs/reference/ is listed under a Reference category at any depth, so its folder
    # matches where readers find it.
    def misplaced_reference_pages(item)
      return item.flat_map { |child| misplaced_reference_pages(child) } if item.is_a?(Array)
      return misplaced_category_pages(item) if item.is_a?(Hash) && item['type'] == 'category'

      reference_doc_ids(node(item))
    end

    def misplaced_category_pages(item)
      return [] if item['label'] == 'Reference'

      misplaced_reference_pages(item.fetch('items')) + reference_doc_ids(landing_items(item['link']))
    end

    def reference_doc_ids(entries)
      entries.filter_map { |kind, value| value if kind == :doc && value.start_with?('reference/') }
    end

    def landing_items(item)
      return [] if item.nil?
      raise ArgumentError, 'Expected a category link object' unless item.is_a?(Hash)
      if item['type'] == 'generated-index'
        raise ArgumentError, 'Category landings must name a checked doc; use type: doc with its id.'
      end
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

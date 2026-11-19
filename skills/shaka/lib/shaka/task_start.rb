# frozen_string_literal: true

require_relative 'error'
require_relative 'publication/publication'
require_relative 'publication/wip_details'

module Shaka
  # Renders the comment that tells an issue its task started, with the same fields as WIP Details.
  class TaskStart
    FIELDS = %w[identity summary wip].freeze
    # The helper adds this from the host's publisher settings; it never comes from the content file.
    HELPER_FIELDS = %w[publisher_note].freeze

    def self.compose(content, path_redaction: nil)
      validate(content)
      settings = Struct.new(:path_redaction).new(path_redaction)
      Publication.new(content, settings:).render([:wip])
    end

    # Keyed by owner tag: the same owner's retry replaces its comment, and a new owner posts its own.
    def self.key(content)
      tag = content.dig('wip', 'owner').to_s.split('·', -1).map(&:strip)[2]
      tag ? "start-#{tag}" : 'start'
    end

    def self.validate(content)
      raise Error, 'Publication content must be an object.' unless content.is_a?(Hash)

      unsupported = content.keys - FIELDS - HELPER_FIELDS
      raise Error, "Unsupported start content: #{unsupported.join(', ')}." unless unsupported.empty?
      raise Error, 'A start comment needs the wip object.' unless content['wip']
    end
  end
end

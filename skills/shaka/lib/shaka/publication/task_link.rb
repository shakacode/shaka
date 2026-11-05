# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # A tracker task carries a link or a visible explanation, never a silently omitted URL.
  module TaskLink
    FIELDS = %w[task_url task_url_omission_reason].freeze
    # Excludes credentials, empty hosts, and characters that can break the Markdown link.
    URL = %r{\Ahttps://[A-Za-z0-9][^\s()<>\[\]\\/?#@]*(?:[/?#][^\s()<>\[\]\\]*)?\z}

    def self.validate!(spec)
      fields = spec.keys & FIELDS
      if spec['task_source'] == 'description' || spec.key?('task_number')
        raise Error, 'Prompt and numbered GitHub tasks do not take task URL fields.' if fields.any?

        return
      end

      unless fields.one?
        raise Error, 'Publication provenance requires exactly one of task_url or task_url_omission_reason.'
      end

      validate_value!(spec, fields.first)
    end

    def self.validate_value!(spec, field)
      if field == 'task_url_omission_reason'
        PublicationText.single_line(spec[field], "provenance #{field}")
      elsif !spec[field].is_a?(String) || !spec[field].match?(URL)
        raise Error, 'Publication provenance task_url must be a safe https URL.'
      end
    end

    def self.render(name, spec)
      return "[#{name}](#{spec['task_url']})" if spec.key?('task_url')

      reason = spec['task_url_omission_reason']
      reason ? "#{name} · URL omitted: #{reason}" : name
    end

    private_class_method :validate_value!
  end
end

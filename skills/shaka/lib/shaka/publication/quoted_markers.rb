# frozen_string_literal: true

require_relative '../error'
require_relative 'human_comments'
require_relative 'verification_line'

module Shaka
  # Shaka finds its regions by reading its own HTML-comment markers back from the body,
  # so supplied description text that quotes one would leave the next read ambiguous.
  # The paragraph after the marked Verification line counts as Setup gaps when it is the helper's
  # sentence, so supplied text cannot start a line with that label either (issue #1344).
  module QuotedMarkers
    MARKER = %r{<!--\s*/?shaka:[\w:.-]*}
    GAPS = /^#{Regexp.escape(VerificationLine::GAPS)}/

    module_function

    # Carried usage blocks come from a body carry already checked, and hold markers by design.
    # Human comments are GitHub's raw read; their excerpts drop HTML comments before rendering.
    def refuse!(content)
      usage = content['usage']
      supplied = content.except(HumanComments::KEY)
      walk(usage.is_a?(Hash) ? supplied.merge('usage' => usage.except('carried')) : supplied, 'content')
    end

    def walk(value, path)
      case value
      when Hash then value.each { |key, item| walk(item, "#{path}.#{key}") }
      when Array then value.each_with_index { |item, index| walk(item, "#{path}[#{index}]") }
      when String then refuse_string(value, path)
      end
    end

    def refuse_string(text, path)
      refuse_gaps(text, path)
      quoted = text[MARKER] or return

      name = quoted.sub(/\A<!--\s*/, '')
      raise Error, "#{path.delete_prefix('content.')} quotes the Shaka marker `#{quoted}`; Shaka reads that " \
                   "marker back from the pull request body. Name it without `<!--`, such as `#{name}`."
    end

    def refuse_gaps(text, path)
      return unless text.match?(GAPS)

      raise Error, "#{path.delete_prefix('content.')} starts a line with `#{VerificationLine::GAPS}`; Shaka reads " \
                   'that label back as its own setup gaps. Reword the line so it starts differently.'
    end
  end
end

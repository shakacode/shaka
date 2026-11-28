# frozen_string_literal: true

require_relative '../error'
require_relative 'human_comments'
require_relative 'verification_line'

module Shaka
  # Shaka finds its regions by reading its own HTML-comment markers back from the body,
  # so supplied description text that quotes one would leave the next read ambiguous.
  module QuotedMarkers
    MARKER = %r{<!--\s*/?shaka:[\w:.-]*}

    module_function

    # Carried usage blocks come from a body carry already checked, and hold markers by design.
    # Human comments are GitHub's raw read; their excerpts drop HTML comments before rendering.
    def refuse!(content)
      usage = content['usage']
      supplied = content.except(HumanComments::KEY)
      walk(usage.is_a?(Hash) ? supplied.merge('usage' => usage.except('carried')) : supplied, 'content')
      refuse_gaps(content['verification'])
    end

    def walk(value, path)
      case value
      when Hash then value.each { |key, item| walk(item, "#{path}.#{key}") }
      when Array then value.each_with_index { |item, index| walk(item, "#{path}[#{index}]") }
      when String then refuse_string(value, path)
      end
    end

    def refuse_string(text, path)
      quoted = text[MARKER] or return

      name = quoted.sub(/\A<!--\s*/, '')
      raise Error, "#{path.delete_prefix('content.')} quotes the Shaka marker `#{quoted}`; Shaka reads that " \
                   "marker back from the pull request body. Name it without `<!--`, such as `#{name}`."
    end

    # Issue #1344: without real gaps the summary follows the marked line, and the reader strips that
    # paragraph and keeps it as setup gaps when it matches the helper's sentence.
    def refuse_gaps(verification)
      summary = verification['summary'] if verification.is_a?(Hash)
      return unless summary.is_a?(String) && summary.strip.start_with?(VerificationLine::GAPS)

      raise Error, "verification.summary starts with `#{VerificationLine::GAPS}`; Shaka reads that label back " \
                   'as its own setup gaps. Reword the summary so it starts differently.'
    end
  end
end

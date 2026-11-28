# frozen_string_literal: true

# Measures the description prose the agent wrote, so the length limit leaves out the helper's own lines.

require_relative 'opening_prose'
require_relative 'visible_prose'

module Shaka
  # Counts the words in a description's prose fields as the agent wrote them. Only the body of a collapsed details
  # block, link and image addresses, and image text are left out, and an inline code span is one word. It reads the
  # content rather than GitHub's rendering, so the count is the same when GitHub refuses its renderer, and it does not
  # try to repeat GitHub's Markdown rules. The publisher note is left out: Shaka's publisher attribution writes it.
  module SuppliedProse
    module_function

    def words(content) = VisibleProse.words(VisibleProse.new(markdown(content)).paragraphs.flatten.join(' '))

    def markdown(content)
      pieces = [*lead(content), *intent(object(content['intent'])), *trailing(content)]
      pieces.filter_map { written(it) if it.is_a?(String) }.join("\n\n")
    end

    def lead(content) = [content['summary'], *Array(content['decisions']), object(content['checkpoint'])['next_action']]

    def trailing(content)
      [*OpeningProse.verification_lines(object(content['verification'])).map(&:last),
       object(content['risk_record'])['summary'], *Array(content['sections']).map { object(it)['body'] }]
    end

    def intent(spec)
      understanding = spec['task_understanding']
      [*OpeningProse::INTENT.keys.map { spec[it] },
       *(understanding.is_a?(Hash) ? understanding.values_at('goal', 'done_when') : [understanding]),
       *Array(spec['review_focus']).map { object(it)['reason'] }]
    end

    def object(value) = value.is_a?(Hash) ? value : {}

    # VisibleProse then drops collapsed details and HTML tags.
    def written(text)
      text.gsub(/!\[[^\]]*\]\([^)]*\)/, '').gsub(/(`+).+?\1/m, ' Code ')
          .gsub(/\]\([^)]*\)/, ']').gsub(/\]\[[^\]]*\]/, ']')
    end
  end
end

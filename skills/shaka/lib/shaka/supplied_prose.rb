# frozen_string_literal: true

# Measures the description prose the agent wrote, so the length limit leaves out the helper's own lines.

require_relative 'opening_prose'
require_relative 'visible_prose'

module Shaka
  # Counts the words in a description's prose fields exactly as the agent wrote them, without interpreting Markdown,
  # so the count is predictable and the same when GitHub refuses its renderer. Each space-separated piece holding a
  # letter or digit is one word. The publisher note is left out: Shaka's publisher attribution writes it.
  module SuppliedProse
    module_function

    def words(content) = VisibleProse.words(text(content))

    def text(content)
      [*lead(content), *intent(object(content['intent'])), *trailing(content)].grep(String).join("\n\n")
    end

    # A task given without a link shows the agent's reason for omitting it.
    def lead(content)
      [content['summary'], *Array(content['decisions']), object(content['checkpoint'])['next_action'],
       object(content['provenance'])['task_url_omission_reason']]
    end

    def intent(spec)
      understanding = spec['task_understanding']
      [*OpeningProse::INTENT.keys.map { spec[it] },
       *(understanding.is_a?(Hash) ? understanding.values_at('goal', 'done_when') : [understanding]),
       *Array(spec['review_focus']).map { object(it)['reason'] }]
    end

    def trailing(content)
      [*OpeningProse.verification_lines(object(content['verification'])).map(&:last),
       object(content['risk_record'])['summary'],
       *Array(content['sections']).flat_map { object(it).values_at('heading', 'body') }]
    end

    def object(value) = value.is_a?(Hash) ? value : {}
  end
end

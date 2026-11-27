# frozen_string_literal: true

require_relative '../error'
require_relative 'text'

module Shaka
  # Renders the agent's restatement of the task under the Task line, so readers and the checkpoint compare
  # the result with the goal the agent worked toward.
  module TaskUnderstanding
    FIELDS = { 'goal' => 'Goal', 'done_when' => 'Done when' }.freeze
    CONFIRMED = 'confirmed'

    module_function

    # The understanding nests under the Task line, so every paragraph reads as part of the task.
    def with_task(task, value)
      return [*task] if value.nil?

      ["#{task || '**Task as understood:**'}\n#{items(value).join("\n")}"]
    end

    # Callers supply the goal and its success criteria; text from older callers keeps its paragraphs.
    def items(value)
      return [legacy(value)] unless value.is_a?(Hash)

      extra = value.keys - FIELDS.keys - [CONFIRMED]
      raise Error, "Publication intent task_understanding has unknown keys: #{extra.join(', ')}." if extra.any?

      FIELDS.map do |field, label|
        "- **#{label}:** #{PublicationText.single_line(value[field], "intent task_understanding #{field}")}"
      end + confirmation(value)
    end

    # Whether a person, not another agent's brief, confirmed the restatement.
    def confirmation(value)
      return [] unless value.key?(CONFIRMED)

      shown = { true => 'Yes', false => 'No' }.fetch(value[CONFIRMED]) do
        raise Error, 'Publication intent task_understanding confirmed must be true or false.'
      end
      ["- **Confirmed by a person:** #{shown}"]
    end

    def legacy(value)
      paragraphs = PublicationText.required(value, 'intent task_understanding').strip.split(/\n\s*\n/)
      "- **As understood:** #{paragraphs.map { |text| text.strip.gsub("\n", "\n  ") }.join("\n\n  ")}"
    end

    private_class_method :items, :confirmation, :legacy
  end
end

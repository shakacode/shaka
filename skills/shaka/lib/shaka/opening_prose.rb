# frozen_string_literal: true

module Shaka
  # What a description's author wrote that a reader sees without opening anything. Lines the helper writes,
  # such as review effort and the validation gate, stay out because the author cannot reword them.
  module OpeningProse
    INTENT = { 'why' => 'Why', 'root_cause' => 'Root cause', 'safe_because' => 'Safe because',
               'leaves_out' => 'Leaves out', 'scope' => 'Scope' }.freeze

    module_function

    def call(content)
      intent, verification = content.values_at('intent', 'verification')
      lines = [*INTENT.map { |field, label| [label, intent[field]] },
               *Array(intent['review_focus']).map { |entry| ['Closer reading', entry['reason']] },
               ['Verification', verification['summary']], ['Not verified', verification['merge_limitations']]]
      lines.filter_map { |label, text| "#{label}: #{text}" unless text.to_s.strip.empty? }.join("\n")
    end
  end
end

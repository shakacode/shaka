# frozen_string_literal: true

require_relative 'publication/intent_verification'

module Shaka
  # What a description's author wrote that a reader sees without opening anything. Lines the helper writes,
  # such as the validation gate, stay out because the author cannot reword them.
  module OpeningProse
    INTENT = { 'why' => 'Why', 'root_cause' => 'Root cause', 'safe_because' => 'Safe because',
               'leaves_out' => 'Leaves out', 'scope' => 'Scope' }.freeze

    module_function

    def call(content)
      intent, verification = content.values_at('intent', 'verification')
      lines = [*INTENT.map { |field, label| [label, intent[field]] },
               *Array(intent['review_focus']).map { |entry| ['Flagged by the implementer', entry['reason']] },
               *verification_lines(verification)]
      lines.filter_map { |label, text| "#{label}: #{text}" unless text.to_s.strip.empty? }.join("\n")
    end

    # The description omits a gap line that reports nothing, so the check skips it too.
    def verification_lines(spec)
      gaps = { 'Not verified' => 'not_verified', 'Merge limitations' => 'merge_limitations' }
      [['Verification', spec['summary']],
       *gaps.filter_map { |label, key| [label, spec[key]] unless IntentVerification.proved?(spec[key]) }]
    end
  end
end

# frozen_string_literal: true

require_relative 'publication/intent_verification'

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
               *verification_lines(verification)]
      lines.filter_map { |label, text| "#{label}: #{text}" unless text.to_s.strip.empty? }.join("\n")
    end

    # The description omits a Not verified line that reports nothing unproven, so the check skips it too.
    def verification_lines(spec)
      unproven = spec['not_verified'] unless spec['not_verified'].to_s.strip.match?(IntentVerification::PROVED)
      [['Verification', spec['summary']], ['Not verified', unproven], ['Merge limitations', spec['merge_limitations']]]
    end
  end
end

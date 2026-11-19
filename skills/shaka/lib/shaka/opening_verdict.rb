# frozen_string_literal: true

module Shaka
  # Rule, applied in code: flag a first sentence whose actor is not reader-facing, or is a thing given an
  # action only a person can perform, and any term the model listed as unclear.
  module OpeningVerdict
    def verdict(sentences, terms = [])
      first = flag_reason(sentences.first)
      reasons = [first, terms_reason(terms)].compact
      return { 'status' => 'passed', 'parse' => sentences } if reasons.empty?

      { 'status' => 'flagged', 'parse' => sentences, 'reason' => reasons.join(' '), 'terms_only' => first.nil? }
    end

    private

    def flag_reason(first)
      if !first['reader_facing']
        "The first sentence's subject, \"#{first['character']}\", is not something a maintainer cares about. " \
          'Rewrite it so the person, pull request, issue, or repository the change affects leads, then publish again.'
      elsif !first['character_can_act']
        "The first sentence gives \"#{first['character']}\" an action it cannot perform: \"#{first['action']}\". " \
          'Make a person the subject, or give the thing what it does itself, then publish again.'
      end
    end

    def terms_reason(terms)
      return if terms.empty?

      listed = terms.map { "\"#{it['term']}\" in #{it['where']} (plainer: \"#{it['plain_wording']}\")" }
      "A maintainer new to this tool may not follow #{listed.join('; ')}. " \
        'Reword any they would stumble on, then publish again.'
    end
  end
end

# frozen_string_literal: true

module Shaka
  # Rule, applied in code: flag a first sentence whose actor is not reader-facing, is a thing given an
  # action only a person can perform, or only keeps a state while the parse finds actions it hides,
  # and any term the model listed as unclear.
  module OpeningVerdict
    # Changes whenever a rule below changes, so cached verdicts from older rules are not reused.
    RULES_VERSION = 2
    # A main verb that reports a lasting condition rather than an event, such as "keeps its decisions".
    STATE_VERBS = %w[keep keeps has have remain remains stay stays retain retains].freeze
    # Words that can precede the main verb without making it an event, such as "no longer keeps".
    VERB_MODIFIERS = %w[no longer still now always never again also only].freeze

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
      elsif (verb = state_verb(first['action'])) && !first['hidden_actions'].empty?
        state_reason(verb, first['hidden_actions'])
      end
    end

    # Returns the verb when the action is a lone state verb, so "has stopped deleting" is not one.
    def state_verb(action)
      words = action.downcase.scan(/[a-z']+/).drop_while { VERB_MODIFIERS.include?(it) }
      words.first if words.one? && STATE_VERBS.include?(words.first)
    end

    def state_reason(verb, hidden)
      found = hidden.map { "\"#{it}\"" }.join(', ')
      "The first sentence's main verb, \"#{verb}\", only states a condition, so it hides what changed " \
        "(the parse found #{found}, which may not be the change). " \
        'Make what now happens, or stops happening, the verb, then publish again.'
    end

    def terms_reason(terms)
      return if terms.empty?

      listed = terms.map { "\"#{it['term']}\" in #{it['where']} (plainer: \"#{it['plain_wording']}\")" }
      "A maintainer new to this tool may not follow #{listed.join('; ')}. " \
        'Reword any they would stumble on, then publish again.'
    end
  end
end

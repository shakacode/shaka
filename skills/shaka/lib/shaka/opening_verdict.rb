# frozen_string_literal: true

module Shaka
  # Rule, applied in code: flag a first sentence whose actor is not reader-facing, is a thing given an
  # action only a person can perform, or only states a condition while hiding actions the parse found,
  # and any term the model listed as unclear.
  module OpeningVerdict
    # Bump this with any rule change below, so verdicts cached under older rules are not reused.
    RULES_VERSION = 2
    # A finite main verb that reports a lasting condition rather than an event, such as "keeps its decisions".
    # Base forms stay out, so "starts to retain" and "doesn't keep" read as the events they name.
    STATE_VERBS = %w[keeps has remains stays retains].freeze
    # Words that say the condition is new, such as "now keeps" or "no longer has", so the change is stated.
    CHANGE_MARKERS = %w[now longer again anymore].freeze

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
        "The first sentence's main verb, \"#{verb}\", states a condition without saying what changed. " \
          'Make what now happens, or stops happening, the verb, then publish again.'
      end
    end

    # The main verb ends the action, so "has stopped deleting" and "keeps publishing" are events.
    def state_verb(action)
      words = action.downcase.scan(/[a-z]+/)
      words.last if STATE_VERBS.include?(words.last) && !words.intersect?(CHANGE_MARKERS)
    end

    def terms_reason(terms)
      return if terms.empty?

      listed = terms.map { "\"#{it['term']}\" in #{it['where']} (plainer: \"#{it['plain_wording']}\")" }
      "A maintainer new to this tool may not follow #{listed.join('; ')}. " \
        'Reword any they would stumble on, then publish again.'
    end
  end
end

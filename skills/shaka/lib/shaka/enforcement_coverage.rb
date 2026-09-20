# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Matches the audited quotes against the workflow they claim to quote.
  #
  # An audit that drifts from the procedure is worse than none, so this fails both ways: on a
  # quote the workflow no longer contains, and on a rule the workflow states that no entry
  # classifies.
  class EnforcementCoverage
    # The four imperative and prohibitive forms workflow.yml uses to state a rule.
    MARKER = /\b(?:never|must|do not|only when)\b/i

    # Phase bodies carry their completion condition, and the two standing sections state rules
    # too. Fenced command listings are dropped: they are syntax, not prose stating a rule.
    def self.sections(workflow)
      sections = workflow.fetch('phases').to_h do |phase|
        [phase.fetch('id'), "#{phase.fetch('body')} #{phase.fetch('done_when')}"]
      end
      sections['always'] = workflow.fetch('always')
      sections['code_quality'] = workflow.fetch('code_quality')
      sections.transform_values { |text| normalize(text) }
    end

    def self.normalize(text) = text.gsub(/```.*?```/m, ' ').gsub(/\s+/, ' ').strip

    def initialize(workflow)
      @sections = self.class.sections(workflow)
    end

    def check(rules)
      located = @sections.transform_values { [] }
      rules.each { |rule| located.fetch(section(rule)) << locate(rule) }
      complete!(located)
    end

    private

    def section(rule)
      id = rule['phase']
      raise Error, "rule #{rule['id']} names no workflow section" unless @sections.key?(id)

      id
    end

    # One unambiguous span per quote, so the completeness check can trust its offsets.
    def locate(rule)
      text = @sections.fetch(rule.fetch('phase'))
      quote = self.class.normalize(rule.fetch('quote'))
      at = text.index(quote)
      raise Error, "rule #{rule['id']} quotes text the #{rule['phase']} section does not contain" unless at
      raise Error, "rule #{rule['id']} quotes #{rule['phase']} text that appears twice" if text.index(quote, at + 1)

      [at, at + quote.length]
    end

    # A rule added to workflow.yml fails here until an entry classifies what enforces it.
    def complete!(located)
      @sections.each do |id, text|
        text.to_enum(:scan, MARKER).each do
          at = Regexp.last_match.begin(0)
          next if located.fetch(id).any? { |from, to| at >= from && at < to }

          raise Error, "enforcement.yml classifies no rule for #{id}: \"#{text[at, 60]}\""
        end
      end
    end
  end
end

# frozen_string_literal: true

# Refuses a description or walkthrough whose rendered, visible prose is shaped as a wall of text
# or cites review findings by an ID only the review ledger explains.

require_relative 'defaults'
require_relative 'error'
require_relative 'visible_prose'

module Shaka
  # Keeps visible prose short enough that the reader reviews the code instead of reading about it.
  class ProseLimits
    DEFAULTS = Defaults.fetch('prose_limits')
    # Room for a short summary however small the change is.
    BASE_WORDS = 150
    QUOTED_WORDS = 8
    FINDING_ID = /(?<![[:alnum:]_.-])N\d{1,3}(?![[:alnum:]_-]|\.\d)/
    # A range such as N3-N5 names both ends; N3-N5D is not a range.
    FINDING_RANGE = /(N\d{1,3})-(?=N\d{1,3}(?![[:alnum:]_-]|\.\d))/
    ADVICE = 'Split long sentences and paragraphs, move supporting detail into details, ' \
             'and link to the code instead of retelling it. Each labeled field renders on its own line, ' \
             'so after trimming, check that every field still makes sense without its neighbors.'

    def self.validate!(limits)
      raise Error, 'prose_limits must be a mapping' unless limits.is_a?(Hash) && limits.keys.all?(String)

      unknown = limits.keys - DEFAULTS.keys
      raise Error, "unknown prose_limits key: #{unknown.first}" unless unknown.empty?

      limits.each do |key, value|
        raise Error, "prose_limits.#{key} must be a positive integer" unless value.is_a?(Integer) && value.positive?
      end
    end

    # Uses established private settings or trusted team settings, never a tracked candidate fallback.
    def self.from_ref(root:, ref:)
      return new unless ref

      require_relative 'configuration'
      new(Configuration.resolve_source(root:, ref:, candidate_commands: false).first.prose_limits)
    end

    # GitHub may omit the size; the proportional budget is then skipped.
    def self.changed_lines(pull)
      additions, deletions = pull.values_at('additions', 'deletions')
      additions + deletions if additions.is_a?(Integer) && deletions.is_a?(Integer)
    end

    def initialize(limits = {})
      self.class.validate!(limits)
      @limits = DEFAULTS.merge(limits)
    end

    def to_h = @limits.dup

    # Measures GitHub's rendering of body; the pull request supplies the change size.
    def verify_publication!(github, body, kind:, pull:)
      verify!(github.markdown(body), kind:, changed_lines: self.class.changed_lines(pull))
    end

    # html is GitHub's rendering, so Markdown rules come from GitHub rather than a copy of them.
    def verify!(html, kind:, changed_lines:)
      paragraphs = VisibleProse.new(html).paragraphs
      problems = finding_ids(paragraphs) + long_sentences(paragraphs) + long_paragraphs(paragraphs) +
                 [length_problem(paragraphs, kind, changed_lines)].compact
      return if problems.empty?

      raise Error, "#{kind.to_s.capitalize} is hard to read: #{problems.join('; ')}. #{ADVICE}"
    end

    private

    # Review ledgers usually number findings N1, N2, and so on. A PR reader never sees the ledger, so a
    # bare ID such as "accepted on N3" tells them nothing (PR #1301). Shorter schemes such as F1
    # collide with ordinary terms, so only this form is checked. Inline code is not scanned, so an
    # author writes another term of that shape as code.
    def finding_ids(paragraphs)
      ids = paragraphs.flatten.flat_map { |sentence| sentence.gsub(FINDING_RANGE, '\1 ').scan(FINDING_ID) }.uniq
      return [] if ids.empty?

      ["it cites review findings by ledger ID (#{ids.join(', ')}), which a reader cannot look up; " \
       'say what each finding is without its ID, and format a term that is not a finding ID, such as an N2 ' \
       'machine type, as code']
    end

    def long_sentences(paragraphs)
      limit = @limits.fetch('max_sentence_words')
      paragraphs.flatten.filter_map do |sentence|
        count = VisibleProse.words(sentence)
        next if count <= limit

        "a sentence has #{count} words (limit #{limit}): #{quote(sentence)}, #{overage(count, limit)}"
      end
    end

    def long_paragraphs(paragraphs)
      limit = @limits.fetch('max_paragraph_words')
      paragraphs.filter_map do |sentences|
        count = VisibleProse.words(sentences.join(' '))
        next if count <= limit

        "a paragraph has #{count} words (limit #{limit}): #{quote(sentences.first)}, #{overage(count, limit)}"
      end
    end

    def length_problem(paragraphs, kind, changed_lines)
      limit = budget(kind, changed_lines)
      count = VisibleProse.words(paragraphs.flatten.join(' '))
      return unless limit && count > limit

      scaled = kind == :walkthrough || limit != @limits.fetch('max_description_words')
      scope = scaled ? " for #{changed_lines} changed lines" : ''
      "the visible prose has #{count} words (limit #{limit}#{scope}), #{overage(count, limit)}"
    end

    def overage(count, limit)
      excess = count - limit
      "#{excess} #{excess == 1 ? 'word' : 'words'} over"
    end

    def budget(kind, changed_lines)
      scaled = BASE_WORDS + (@limits.fetch('words_per_changed_line') * changed_lines) if changed_lines
      return scaled if kind == :walkthrough

      [scaled, @limits.fetch('max_description_words')].compact.min
    end

    def quote(text)
      words = text.split
      "“#{words.first(QUOTED_WORDS).join(' ')}#{'…' if words.size > QUOTED_WORDS}”"
    end
  end
end

# frozen_string_literal: true

require 'cgi'
require_relative '../error'
require_relative '../publication'
require_relative '../reviewer_selection'
require_relative 'evidence'

module Shaka
  # Renders one pull request comment for a local adversarial review: a summary a reader skims,
  # each report collapsed beneath it, and the last round's attestation as the closing line,
  # which is where `merge` reads review evidence.
  class LocalReviewComment
    KEY = 'local-adversarial-review'
    TITLE = '# Local Adversarial Review'
    COLUMNS = %w[Round Commit Reviewer Model Effort Prompt Findings Tokens Cost].freeze
    OUTCOMES = %w[different_provider same_provider same_model].freeze
    SETUP_GUIDE = 'https://github.com/shakacode/shaka/blob/main/docs/settings.md#add-a-second-reviewer'
    CLOSING = /EFFORT (\S+) FINDINGS (\d+)\s*\z/
    def self.render(content) = new(content).render

    def initialize(content)
      raise Error, 'Local review content must be an object.' unless content.is_a?(Hash)

      rounds = PublicationText.list(content['rounds'], 'rounds')
      raise Error, 'Local review content needs at least one round.' if rounds.empty?

      @rounds = rounds.each_with_index.map { |round, index| Round.new(round, index + 1) }
      @fallback = content['fallback']
    end

    def render
      blocks = [TITLE, table, *fallback_notice, *@rounds.map(&:details), @rounds.last.attestation]
      "#{blocks.join("\n\n")}\n"
    end

    # Reports are published verbatim, so a stray fence or disclosure tag in one can swallow the rest
    # of the comment. GitHub's own rendering decides that; a regex over Markdown cannot.
    def check_rendering!(html)
      closing = %r{<p\b[^>]*>#{Regexp.escape(CGI.escapeHTML(@rounds.last.attestation))}</p>\s*\z}
      disclosures = [html.scan(/<details\b/).size, html.scan('</details>').size]
      return if html.match?(closing) && disclosures == [@rounds.size] * 2 && summaries_in_order?(html)

      raise Error, 'A review report leaves its markup open or adds disclosure tags, so GitHub would not show ' \
                   'each round collapsed with the attestation last. Fix the report and publish again.'
    end

    private

    # A fence opened in one report and closed in the next hides the boundary between them, including
    # the next round's own summary; balanced tags the reports supply cannot stand in for it.
    def summaries_in_order?(html)
      offset = 0
      @rounds.all? do |round|
        found = html.index("<summary>#{round.summary}</summary>", offset)
        offset = found + 1 if found
      end
    end

    def table
      rows = @rounds.map { |round| line(round.cells) }
      [line(COLUMNS), line(['---'] * COLUMNS.size), *rows].join("\n")
    end

    # Escaping backslashes first keeps a supplied `\|` from ending its cell early.
    def line(cells) = "| #{cells.map { |cell| cell.gsub(/[\\|]/) { |char| "\\#{char}" } }.join(' | ')} |"

    def fallback_notice
      return [] if @fallback.nil?
      raise Error, 'Local review fallback must be an object.' unless @fallback.is_a?(Hash)

      outcome = @fallback['outcome']
      raise Error, "Local review fallback outcome must be one of #{OUTCOMES.join(', ')}." unless
        OUTCOMES.include?(outcome)
      return [] if outcome == 'different_provider'

      [(['**Reviewer fallback:** no reviewer from a different provider ran, so this review ' \
         "used `#{outcome}`. [Add a second reviewer](#{SETUP_GUIDE}) to avoid this."] + attempts).join("\n")]
    end

    # Selection can fall back without trying anything, as when no other provider is configured.
    def attempts
      tried = PublicationText.list(@fallback['attempts'], 'fallback attempts')
      return [] if tried.empty?

      ['', 'Tried:', ''] + tried.map { |attempt| attempt_line(attempt) }
    end

    def attempt_line(attempt)
      raise Error, 'Each fallback attempt must be an object.' unless attempt.is_a?(Hash)

      reviewer = PublicationText.single_line(attempt['reviewer'], 'fallback reviewer')
      stage = PublicationText.single_line(attempt['failure_stage'], 'fallback failure_stage')
      reason = PublicationText.single_line(attempt['reason'], 'fallback reason')
      "- `#{reviewer}`: `#{stage}`: #{reason}"
    end

    # One reviewed commit, its reviewer settings, and the report whose attestation it carries.
    class Round
      attr_reader :head

      def initialize(spec, number)
        raise Error, "Local review round #{number} must be an object." unless spec.is_a?(Hash)

        @spec = spec
        @number = number
        @head = spec['head'].to_s
        raise Error, "Round #{number} head must be a full commit SHA." unless @head.match?(LocalReviewEvidence::SHA)

        # Parsed as `merge` parses it, so a comment merge would ignore is never published.
        @reviewer = ReviewerSelection.parse(field('reviewer')).values.map(&:downcase).join('/')
        @report = read_report
      end

      def cells
        effort, findings = @report.match(CLOSING).captures
        [@number.to_s, "`#{@head[0, 7]}`", @reviewer, optional('model'), effort, prompt, findings,
         optional('tokens'), optional('cost')]
      end

      def summary
        effort, findings = @report.match(CLOSING).captures
        noun = findings == '1' ? 'finding' : 'findings'
        PublicationText.summary_text("Round #{@number} · #{@head[0, 7]} · #{@reviewer} · " \
                                     "effort #{effort} · #{findings} #{noun}", 'round summary')
      end

      def details = "<details>\n<summary>#{summary}</summary>\n\n#{@report.strip}\n\n</details>"

      def attestation = @report.strip.lines.last.strip

      private

      def prompt
        source = optional('prompt_source', 'Shaka default')
        ref = @spec['criteria_ref']
        return "#{source} · criteria not supplied" if ref.nil?
        raise Error, "Round #{@number} criteria_ref must be a full commit SHA." unless
          ref.to_s.match?(LocalReviewEvidence::SHA)

        "#{source} · criteria `#{ref[0, 7]}`"
      end

      def field(name) = PublicationText.single_line(@spec[name], "round #{@number} #{name}").strip

      def optional(name, default = 'UNKNOWN')
        value = @spec[name]
        value.nil? || (value.is_a?(String) && value.strip.empty?) ? default : field(name)
      end

      def read_report
        path = field('report')
        text = File.read(path, encoding: 'UTF-8')
        raise Error, "Round #{@number} report is not UTF-8." unless text.valid_encoding?
        unless LocalReviewEvidence.valid?(text, head: @head, reviewer: @reviewer)
          raise Error, "Round #{@number} report does not close with REVIEWED #{@head} BY #{@reviewer}."
        end

        text
      end
    end
  end
end

# frozen_string_literal: true

require_relative 'publication/managed_region'
require_relative 'publication/verification_line'

module Shaka
  # The results a description already shows for its head. Only `description` reads this, to
  # repeat that text; `evidence bind` and `evidence verify` still compare the results themselves.
  # It stays outside evidence/ so a change here supersedes no earlier result.
  module PublishedResults
    SETTINGS_DRIFT = /\A(?:settings components differ: |public settings snapshot differs)/
    # Helpers before #1325 wrote the full line first in the first Evidence and limitations fold, even
    # when the Verification section showed only a short summary. Agent details items render later,
    # inside that fold. Delete this reading once no open PR was described before #1325.
    FOLD = %r{^<details>\n<summary>Evidence and limitations</summary>\n\n}
    CODES = /`[^`\n]+`(?:, `[^`\n]+`)*/
    COMMENT_LINK = %r{ \(\[review comment\]\(https://[^)\s]+\)\)}
    SHORTFALL = /\d+ of \d+ configured reviewers completed(?:; #{CODES} did not)?(?:#{COMMENT_LINK})?\./
    WHY = Regexp.escape("([why](#{VerificationLine::CONTAINER_GUIDE})).")
    BLIND = /#{CODES} could not start (?:its|their) sandbox, so (?:it|they) reviewed only the diff #{WHY}/
    # Only the sentences the helper writes for a missing reviewer or a sandbox that refused every command.
    GAPS = /#{Regexp.escape(VerificationLine::GAPS)} (?:#{SHORTFALL}(?: #{BLIND})?|#{BLIND})/

    module_function

    # A fork's author can edit its description, so only a same-repository one counts.
    def read(pull, repository)
      return unless pull.dig('head', 'repo', 'full_name').to_s.casecmp?(repository)

      # A person who saved the description in GitHub's editor may have left CRLF line endings.
      region = Publishing.managed_region(pull['body'].to_s.gsub("\r\n", "\n"))
      line, gaps = region && own_line(region, pull.dig('head', 'sha'))
      line && { 'kept_line' => line, 'kept_gaps' => gaps }
    end

    # Supplied text cannot carry a Shaka marker, so only the line after the helper's one marker, which
    # sits alone on its own line, counts, and a summary, section, or check worded like the line is
    # never kept. Returns that line and the helper's Setup gaps sentence when it follows. A
    # description without the marker is read from the top of its one Evidence and limitations fold,
    # where older helpers wrote the line.
    def own_line(region, head)
      marked = region.scan(VerificationLine::MARKER).size
      return legacy_line(region, head) if marked.zero?

      own = region.match(/^#{Regexp.escape(VerificationLine::MARKER)}\n/o) if marked == 1
      own && marked_line(own.post_match, head)
    end

    def marked_line(text, head)
      first, second = text.split("\n\n", 3)
      [first.to_s[/\A#{verified_line(head).source}/], second.to_s.strip[/\A#{GAPS.source}\z/]]
    end

    # A second fold, such as a copied example, leaves the helper's own unclear, so it keeps nothing.
    def legacy_line(region, head)
      fold = region.match(FOLD) if region.scan(FOLD).one?
      line = fold && fold.post_match[/\A#{verified_line(head).source}/]
      [line, line && legacy_gaps(region, line)]
    end

    # Older helpers wrote Setup gaps after the line under the heading and did not repeat them in the fold.
    def legacy_gaps(region, line)
      region[/^## Verification\n\n#{Regexp.escape(line)}[^\n]*\n\n\K#{GAPS.source}(?=$)/]
    end

    # Every required result was supplied, none reports a failure, and only settings keep some from binding.
    def settings_drift?(verdict)
      return false if verdict['status'] == 'ready' || verdict['missing'].any?

      verdict['checks'].values.flatten.all? { |entry| passed?(entry) && drifted_only?(entry) }
    end

    # A review result has no exit code. A check result passed only with an integer 0: one whose code is
    # nil, such as a stopped Windows check whose leader outlived the stop, or an unvalidated value,
    # takes the stale-evidence path instead.
    def passed?(entry)
      original = entry['original'] || {}
      !original.key?('exit_code') || original['exit_code'].eql?(0)
    end

    def drifted_only?(entry)
      entry['status'] == 'bound' || entry['reasons'].all? { |reason| reason.match?(SETTINGS_DRIFT) }
    end

    def verified_line(head)
      /#{Regexp.escape(VerificationLine::LABEL)} (?!UNKNOWN)[^\n]* at `#{Regexp.escape(head.to_s[0, 7])}`\./
    end
    private_class_method :own_line, :marked_line, :legacy_line, :legacy_gaps, :verified_line, :passed?, :drifted_only?
  end
end

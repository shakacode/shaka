# frozen_string_literal: true

require_relative 'publication/managed_region'
require_relative 'publication/verification_line'

module Shaka
  # The results a description already shows for its head. Only `description` reads this, to
  # repeat that text; `evidence bind` and `evidence verify` still compare the results themselves.
  # It stays outside evidence/ so a change here supersedes no earlier result.
  module PublishedResults
    SETTINGS_DRIFT = /\A(?:settings components differ: |public settings snapshot differs)/
    # The helper writes the full line first in the first Evidence and limitations fold, even when the
    # Verification section shows only a short summary. Agent details items render later, inside that fold.
    FOLD = %r{^<details>\r?\n<summary>Evidence and limitations</summary>\r?\n\r?\n}
    CODES = /`[^`\r\n]+`(?:, `[^`\r\n]+`)*/
    COMMENT_LINK = %r{ \(\[review comment\]\(https://[^)\s]+\)\)}
    SHORTFALL = /\d+ of \d+ configured reviewers completed(?:; #{CODES} did not)?(?:#{COMMENT_LINK})?\./
    WHY = Regexp.escape("([why](#{VerificationLine::CONTAINER_GUIDE})).")
    BLIND = /#{CODES} could not start (?:its|their) sandbox, so (?:it|they) reviewed only the diff #{WHY}/
    # Only the sentences the helper writes for a missing reviewer or a sandbox that refused every command.
    GAPS = /#{Regexp.escape(VerificationLine::GAPS)} (?:#{SHORTFALL}(?: #{BLIND})?|#{BLIND})(?=\r?$)/

    module_function

    # A fork's author can edit its description, so only a same-repository one counts. A summary or
    # check worded like the line sits outside the fold, so it never counts.
    def read(pull, repository)
      return unless pull.dig('head', 'repo', 'full_name').to_s.casecmp?(repository)

      region = Publishing.managed_region(pull['body'])
      fold = region&.match(FOLD)
      line = fold && region[fold.end(0)..][/\A#{verified_line(pull.dig('head', 'sha')).source}/]
      line && { 'kept_line' => line, 'kept_gaps' => gaps(region, line) }
    end

    # Setup gaps follow the line under the heading and are not repeated in the fold.
    def gaps(region, line)
      region[/^## Verification\r?\n\r?\n#{Regexp.escape(line)}[^\r\n]*\r?\n\r?\n\K#{GAPS.source}/]
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
      /#{Regexp.escape(VerificationLine::LABEL)} (?!UNKNOWN)[^\r\n]* at `#{Regexp.escape(head.to_s[0, 7])}`\./
    end
    private_class_method :verified_line, :passed?, :drifted_only?, :gaps
  end
end

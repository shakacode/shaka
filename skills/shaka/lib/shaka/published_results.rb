# frozen_string_literal: true

require_relative 'publication/managed_region'
require_relative 'publication/verification_line'

module Shaka
  # The results a description already shows for its head. Only `description` reads this, to
  # repeat that text; `evidence bind` and `evidence verify` still compare the results themselves.
  # It stays outside evidence/ so a change here supersedes no earlier result.
  module PublishedResults
    SETTINGS_DRIFT = /\A(?:settings components differ: |public settings snapshot differs)/
    # The helper writes the full line as the first paragraph of this fold, even when the Verification
    # section shows only a short summary, and agent text can come before or after the fold.
    FOLD = '<summary>Evidence and limitations</summary>'
    HEADING = '## Verification'

    module_function

    # A fork's author can edit its description, so only a same-repository one counts. Only the line in
    # the helper's own place counts: a verification summary or check may repeat the line's wording.
    def read(pull, repository)
      return unless pull.dig('head', 'repo', 'full_name').to_s.casecmp?(repository)

      region = Publishing.managed_region(pull['body'])
      return unless region && only_once?(region, FOLD)

      line = region[after(FOLD, verified_line(pull.dig('head', 'sha')))]
      line && { 'kept_line' => line, 'kept_gaps' => gaps(region, line) }
    end

    # Setup gaps follow the line under the heading and are not repeated in the fold.
    def gaps(region, line)
      return unless only_once?(region, HEADING)

      region[after(HEADING, /#{Regexp.escape(line)}[^\r\n]*\r?\n\r?\n\K#{Regexp.escape(VerificationLine::GAPS)} .+$/)]
    end

    # Agent text that copies the anchor makes it ambiguous, so nothing is kept.
    def only_once?(region, anchor) = region.scan(/^#{Regexp.escape(anchor)}\r?$/).one?

    def after(anchor, pattern) = /^#{Regexp.escape(anchor)}\r?\n\r?\n\K#{pattern.source}/

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
      /#{Regexp.escape(VerificationLine::LABEL)} (?!UNKNOWN).* at `#{Regexp.escape(head.to_s[0, 7])}`\./
    end
    private_class_method :verified_line, :passed?, :drifted_only?, :gaps, :only_once?, :after
  end
end

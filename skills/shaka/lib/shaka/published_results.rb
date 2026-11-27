# frozen_string_literal: true

require_relative 'publication/managed_region'
require_relative 'publication/verification_line'

module Shaka
  # The results a description already shows for its head. Only `description` reads this, to
  # repeat that text; `evidence bind` and `evidence verify` still compare the results themselves.
  # It stays outside evidence/ so a change here supersedes no earlier result.
  module PublishedResults
    SETTINGS_DRIFT = /\A(?:settings components differ: |public settings snapshot differs)/
    GAPS = /\A#{Regexp.escape(VerificationLine::GAPS)} .+\z/
    HEADING = "## Verification\n\n"
    # Descriptions published before the line stopped folding showed this sentence under the heading
    # and the line at the top of the Evidence and limitations fold.
    FOLD = "<summary>Evidence and limitations</summary>\n\n"
    COMPACT = 'Validation passed; local review completed at '

    module_function

    # A fork's author can edit its description, so only a same-repository one counts.
    def read(pull, repository)
      return unless pull.dig('head', 'repo', 'full_name').to_s.casecmp?(repository)

      region = Publishing.managed_region(pull['body'])
      line, gaps = region && own_line(region, pull.dig('head', 'sha').to_s[0, 7])
      line && { 'kept_line' => line, 'kept_gaps' => gaps&.match?(GAPS) ? gaps : nil }
    end

    # Only the paragraph the helper writes under its one Verification heading counts, so a summary or
    # check worded like the line is never kept. Returns that line and the paragraph after it.
    def own_line(region, short_head)
      return unless region.scan(HEADING).one?

      first, second = paragraphs_after(region, HEADING)
      return [first[verified_line(short_head)], second] unless first.to_s.start_with?("#{COMPACT}#{short_head}")
      return unless region.scan(FOLD).one?

      [paragraphs_after(region, FOLD).first.to_s[verified_line(short_head)], nil]
    end

    def paragraphs_after(region, marker) = region.split(marker, 2).last.split("\n\n", 3).first(2).map(&:strip)

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

    def verified_line(short_head)
      /\A#{Regexp.escape(VerificationLine::LABEL)} (?!UNKNOWN).* at `#{Regexp.escape(short_head)}`\./
    end
    private_class_method :own_line, :paragraphs_after, :verified_line, :passed?, :drifted_only?
  end
end

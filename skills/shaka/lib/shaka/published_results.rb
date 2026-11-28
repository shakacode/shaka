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
    # Descriptions published before the marker hold the line under their Verification heading, or,
    # for a routine run, a compact sentence there and the line at the top of the Evidence and
    # limitations fold. Delete this reading once no open PR was described before #1325.
    HEADING = /^## Verification\n\n/
    FOLD = %r{^<summary>Evidence and limitations</summary>\n\n}
    COMPACT = 'Validation passed; local review completed at '

    module_function

    # A fork's author can edit its description, so only a same-repository one counts.
    def read(pull, repository)
      return unless pull.dig('head', 'repo', 'full_name').to_s.casecmp?(repository)

      # A person who saved the description in GitHub's editor may have left CRLF line endings.
      region = Publishing.managed_region(pull['body'].to_s.gsub("\r\n", "\n"))
      line, gaps = region && own_line(region, pull.dig('head', 'sha').to_s[0, 7])
      line && { 'kept_line' => line, 'kept_gaps' => gaps&.match?(GAPS) ? gaps : nil }
    end

    # Supplied text cannot carry a Shaka marker, so only the paragraph after the helper's marker counts,
    # and a summary or check worded like the line is never kept. Returns that line and the paragraph
    # after it. A description without the marker is read where older helpers wrote the line, and
    # keeps nothing when its headings or folds repeat.
    def own_line(region, short_head)
      marked = region.scan(VerificationLine::MARKER).size
      return if marked > 1
      return line_after(region, VerificationLine::MARKER, short_head) if marked == 1
      return unless region.scan(HEADING).one?

      first, second = line_after(region, HEADING, short_head)
      return [first, second] unless paragraphs_after(region, HEADING).first.match?(compact(short_head))

      [line_after(region, FOLD, short_head).first, nil] if region.scan(FOLD).one?
    end

    # The whole sentence older helpers wrote, with or without its evidence link.
    def compact(short_head) = /\A#{Regexp.escape("#{COMPACT}#{short_head}")}(?: \(\[evidence\]\(\S+\)\))?\.\z/

    def line_after(region, marker, short_head)
      first, second = paragraphs_after(region, marker)
      [first[verified_line(short_head)], second]
    end

    # The first paragraph is always a string, so a section that ends at the marker keeps nothing.
    def paragraphs_after(region, marker)
      [*region.split(marker, 2).last.strip.split("\n\n", 3).first(2).map(&:strip), '']
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

    def verified_line(short_head)
      /\A#{Regexp.escape(VerificationLine::LABEL)} (?!UNKNOWN).* at `#{Regexp.escape(short_head)}`\./
    end
    private_class_method :own_line, :compact, :line_after, :paragraphs_after, :verified_line, :passed?, :drifted_only?
  end
end

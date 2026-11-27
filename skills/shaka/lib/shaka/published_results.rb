# frozen_string_literal: true

require_relative 'publication/managed_region'
require_relative 'publication/verification_line'

module Shaka
  # The results a description already shows for its head. Only `description` reads this, to
  # repeat that text; `evidence bind` and `evidence verify` still compare the results themselves.
  # It stays outside evidence/ so a change here supersedes no earlier result.
  module PublishedResults
    SETTINGS_DRIFT = /\A(?:settings components differ: |public settings snapshot differs)/
    HEADING = '## Verification'
    PARAGRAPHS = /\r?\n\r?\n/
    # Every paragraph of the Verification section is one line, and the Evidence and limitations fold
    # follows it. The helper writes the full line first in that fold, even when the section shows only
    # a short summary. A summary, check, or details item that repeats the line's wording sits elsewhere.
    SECTION = %r{^#{Regexp.escape(HEADING)}\r?\n\r?\n(?<section>(?:[^\r\n]+\r?\n\r?\n)+?)
                 <details>\r?\n<summary>Evidence\ and\ limitations</summary>\r?\n\r?\n}x
    # Only the wording the helper writes for a missing reviewer or a sandbox that refused every command.
    GAPS = /\A#{Regexp.escape(VerificationLine::GAPS)}\ (?:\d+\ of\ \d+\ configured\ reviewers\ completed|
            `[^`\r\n]+`(?:,\ `[^`\r\n]+`)*\ could\ not\ start\ (?:its|their)\ sandbox)[^\r\n]*\z/x

    module_function

    # A fork's author can edit its description, so only a same-repository one counts.
    def read(pull, repository)
      return unless pull.dig('head', 'repo', 'full_name').to_s.casecmp?(repository)

      region = Publishing.managed_region(pull['body'])
      found = region&.match(/#{SECTION}(?<line>#{verified_line(pull.dig('head', 'sha')).source})/)
      found && { 'kept_line' => found[:line], 'kept_gaps' => gaps(found[:section], found[:line]) }
    end

    # Setup gaps follow the line under the heading and are not repeated in the fold. A section the agent
    # headed the same way can come first, so the paragraphs after the last heading count.
    def gaps(section, line)
      paragraphs = "#{HEADING}\n\n#{section}".split(PARAGRAPHS)
      shown, gap = paragraphs.drop(paragraphs.rindex(HEADING) + 1)
      gap if shown&.start_with?(line) && gap&.match?(GAPS)
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

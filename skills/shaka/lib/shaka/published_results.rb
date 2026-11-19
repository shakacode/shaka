# frozen_string_literal: true

require_relative 'publication/managed_region'
require_relative 'publication/verification_gates'

module Shaka
  # The results a description already shows for its head. Only `description` reads this, to
  # repeat that text; `evidence bind` and `evidence verify` still compare the results themselves.
  # It stays outside evidence/ so a change here supersedes no earlier result.
  module PublishedResults
    SETTINGS_DRIFT = /\A(?:settings components differ: |public settings snapshot differs)/
    GAPS = /^#{Regexp.escape(VerificationGates::GAPS)} .+$/

    module_function

    # A fork's author can edit its description, so only a same-repository one counts.
    def read(pull, repository)
      return unless pull.dig('head', 'repo', 'full_name').to_s.casecmp?(repository)

      region = Publishing.managed_region(pull['body'])
      line = region && region[verified_line(pull.dig('head', 'sha').to_s[0, 7])]
      line && { 'kept_line' => line, 'kept_gaps' => region[GAPS] }
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
      /^#{Regexp.escape(VerificationGates::LABEL)} (?!UNKNOWN).* at `#{Regexp.escape(short_head)}`\./
    end
    private_class_method :verified_line, :passed?, :drifted_only?
  end
end

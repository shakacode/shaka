# frozen_string_literal: true

require 'json'
require_relative 'error'

module Shaka
  # Product conclusions never use the technical REVIEWED attestation.
  module PostImplementationReport
    CONCLUSIONS = ['Proceed', 'Simplify/reframe', 'Do not merge'].freeze
    # The task owner's dispositions, shared by the owner's checkpoint comment and the description headline.
    RECOMMENDATIONS = ['Merge', 'Merge after maintainer decision', 'Revise before merge', 'Reconsider approach',
                       'Do not merge'].freeze
    # The owner would merge, but concerns, a Simplify/reframe verdict, or another question wait on the maintainer.
    AWAITING_DECISION = 'Merge after maintainer decision'
    # Whether the verification proves the intent. The last two stop an agent merge, never readiness.
    ADEQUACY = ['adequate', 'adequate with accepted gaps', 'inadequate', 'cannot judge'].freeze
    # Fixed because Ruby acts on the parsed verdict, and no maintainer has a use for Auto merging past
    # verification that failed or could not be judged; Ask leaves the decision to the maintainer.
    STOPS_AGENT_MERGE = ['inadequate', 'cannot judge'].freeze
    ADEQUACY_FIELDS = %w[verdict weakest_claim next_check].freeze
    # The reviewer's rating of what a mistake would reach. Unknown is treated as high wherever it is used.
    RISK = %w[low medium high unknown].freeze
    MAX_RISK_REASONS = 5
    # A report from before risk ratings, such as a run published after an upgrade, counts as unknown.
    LEGACY_RISK = { 'rating' => 'unknown',
                    'reasons' => ['This checkpoint ran before risk ratings; rerun it for one.'] }.freeze

    module_function

    def read(path, head:)
      text = File.binread(path, 100_001)
      raise Error, 'Checkpoint report exceeds 100 KB' if text.bytesize > 100_000

      report = JSON.parse(text)
      validate(report, head:)
      report.slice('head', 'conclusion', 'reasons', 'concerns', 'alternative', 'summary', 'next_action')
            .merge('verification_adequacy' => report['verification_adequacy'].slice(*ADEQUACY_FIELDS),
                   'risk' => report.fetch('risk', LEGACY_RISK).slice('rating', 'reasons'))
    rescue JSON::ParserError => e
      raise Error, "Malformed checkpoint report: not valid JSON#{position(e)}"
    end

    # The parser's message quotes the reviewer's text, which can hold escapes publication refuses.
    def position(error)
      " at line #{error.line} column #{error.column}" if error.respond_to?(:line) && error.line
    end

    def validate(report, head:)
      raise Error, 'Checkpoint report must be an object for the current head' unless
        report.is_a?(Hash) && report['head'] == head
      raise Error, 'Checkpoint report has an invalid conclusion' unless CONCLUSIONS.include?(report['conclusion'])

      evidence_fields!(report)
      summary_fields!(report)
      adequacy!(report['verification_adequacy'])
      risk!(report['risk']) if report.key?('risk')
    end

    def risk!(risk)
      raise Error, "Checkpoint risk needs rating (#{RISK.join(', ')}) and reasons" unless
        risk.is_a?(Hash) && RISK.include?(risk['rating'])

      risk_reasons!(risk['reasons'])
    end

    def risk_reasons!(reasons)
      return if reasons.is_a?(Array) && reasons.size.between?(1, MAX_RISK_REASONS) &&
                reasons.all? { |reason| text?(reason) && !reason.match?(/[\r\n]/) }

      raise Error, "Checkpoint risk reasons must be 1 to #{MAX_RISK_REASONS} single-line strings"
    end

    # Single lines, because the checkpoint comment renders them inline.
    def adequacy!(adequacy)
      raise Error, "Checkpoint verification_adequacy needs #{ADEQUACY_FIELDS.join(', ')}" unless
        adequacy.is_a?(Hash) && ADEQUACY_FIELDS.all? { |key| text?(adequacy[key]) && !adequacy[key].match?(/[\r\n]/) }
      raise Error, "Checkpoint verification_adequacy verdict must be one of: #{ADEQUACY.join(', ')}" unless
        ADEQUACY.include?(adequacy['verdict'])
    end

    def evidence_fields!(report)
      %w[reasons concerns].each { |key| strings!(report[key], key) }
      raise Error, 'Checkpoint needs reasons and a simpler alternative' if
        report['reasons'].empty? || !text?(report['alternative'])
    end

    def summary_fields!(report)
      %w[summary next_action].each do |key|
        raise Error, "Checkpoint #{key} must be non-empty text" if report.key?(key) && !text?(report[key])
      end
    end

    def strings!(list, label)
      raise Error, "Checkpoint #{label} must be a list of non-empty strings" unless
        list.is_a?(Array) && list.all? { |entry| text?(entry) }
    end

    def text?(value) = value.is_a?(String) && !value.strip.empty?
    def ready?(report) = report['conclusion'] == 'Proceed' && report['concerns'].empty?
  end
end

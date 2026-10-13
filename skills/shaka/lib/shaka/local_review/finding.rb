# frozen_string_literal: true

require_relative '../error'
require_relative '../publication/text'
require_relative 'evidence'

module Shaka
  # One finding from a local review round, as the author transcribed it, and what became of it.
  # The `id` stays the same when a later round raises the same problem, which is how a fix that
  # did not hold is noticed.
  class LocalReviewFinding
    CLASSES = %w[defect risk nit].freeze
    DISPOSITIONS = %w[open decision_needed fixed dismissed accepted documented].freeze
    STATUSES = { 'open' => 'Open', 'decision_needed' => 'Needs your decision', 'fixed' => 'Fixed',
                 'dismissed' => 'Dismissed', 'accepted' => 'Accepted', 'documented' => 'Unassessed' }.freeze
    ID = /\A[\w.-]{1,40}\z/

    attr_reader :id, :summary, :kind, :disposition, :commit, :note, :reported_as, :decision

    def self.pending?(copies)
      !copies.last.closed? && (copies.last.open? || copies.any? { |finding| finding.kind != 'nit' })
    end

    def self.list(value, label)
      findings = PublicationText.list(value, label).map { |finding| new(finding, label) }
      ids = findings.map(&:id)
      raise Error, "A #{label} id repeats; give each finding in a round its own id." unless ids.uniq == ids

      findings
    end

    def initialize(spec, label)
      raise Error, "Each #{label} entry must be an object." unless spec.is_a?(Hash)

      @label = label
      @id = spec['id'].to_s
      raise Error, "#{label} id must be 1-40 letters, digits, dots, dashes, or underscores." unless @id.match?(ID)

      @summary = text(spec, 'summary')
      @kind = choice(spec['class'], CLASSES, 'class')
      @disposition = choice(spec['disposition'], DISPOSITIONS, 'disposition')
      @commit = spec['commit']
      @note, @reported_as, @decision = optional_texts(spec)
      check_commit!
    end

    def fixed? = @disposition == 'fixed'
    def closed? = %w[fixed dismissed accepted].include?(@disposition)
    def open? = %w[open decision_needed].include?(@disposition)
    def status = STATUSES.fetch(@disposition)

    # What the next round's reviewer sees: never the note, which carries the author's reasoning.
    def label
      return "fixed in #{@commit[0, 7]}" if fixed?

      @disposition == 'documented' ? "documented #{@kind}" : status
    end

    def prompt_line = "- [#{@id}] #{@kind}: #{@summary} (#{label})"

    private

    # `reported_as` is the reporting reviewer's own number, which ties its report to the triage.
    def optional_texts(spec) = %w[note reported_as decision].map { |field| spec[field] && text(spec, field) }

    def text(spec, field) = PublicationText.single_line(spec[field], "#{@label} #{@id} #{field}").strip

    def choice(value, allowed, field)
      return value if allowed.include?(value)

      raise Error, "#{@label} #{@id} #{field} must be one of #{allowed.join(', ')}."
    end

    # A nit is recorded for a later decision, never fixed inside the loop.
    def check_commit!
      raise Error, "#{@label} #{@id} is a nit; nits are documented, not fixed in the loop." if
        fixed? && @kind == 'nit'
      raise Error, "#{@label} #{@id} is fixed, so it needs the fix commit as a full SHA." if
        fixed? && !@commit.to_s.match?(LocalReviewEvidence::SHA)
      raise Error, "#{@label} #{@id} is not fixed, so it takes no commit." if !fixed? && @commit

      check_explanation!
    end

    def check_explanation!
      raise Error, "#{@label} #{@id} needs a note explaining #{@disposition}." if
        %w[dismissed accepted decision_needed].include?(@disposition) && !@note
      raise Error, "#{@label} #{@id} needs the maintainer's decision to accept it." if
        @disposition == 'accepted' && !@decision
    end
  end
end

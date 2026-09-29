# frozen_string_literal: true

require 'json'
require_relative '../error'
require_relative 'evidence'
require_relative 'finding'

module Shaka
  # Private record of a local review loop: each round's commit, reviewer settings, report, and
  # what became of its findings. It stays outside the checkout until `review publish` renders it,
  # and it has the same shape as that command's content file. Rounds that share a commit form a
  # batch: several reviewers read that commit before its findings are recorded and fixed together.
  class LocalReviewLedger
    attr_reader :path

    # Only `review run` can start a ledger, so only it needs the checkout to keep the ledger out of.
    def initialize(path, root: nil)
      @path = File.expand_path(path)
      directory = File.realpath(File.dirname(@path))
      raise Error, '--ledger must be outside the candidate checkout' if
        root && (directory == root || directory.start_with?("#{root}/"))
    end

    def rounds = data.fetch('rounds')

    def last_round_fixes
      batch.flat_map do |index|
        LocalReviewFinding.list(rounds[index]['findings'], "round #{index + 1} finding").select(&:fixed?)
      end.map(&:commit)
    end

    def last_head = rounds.last&.fetch('head')

    # The newest head reviewed before this one: the last batch's commit, or for another reviewer
    # joining the last batch, the batch before it.
    def previous_head(head) = rounds.reverse.find { |round| round['head'] != head }&.fetch('head')

    # A round reviews a new commit on the same base, after the previous batch's findings are
    # recorded, or joins the last batch with a reviewer that has not read that commit.
    def check_next!(base:, head:, reviewer:)
      return if rounds.empty?

      raise Error, "The ledger's rounds measure the change against #{data['base']}; use a new ledger." unless
        data['base'] == base

      check_new_head!(head, reviewer)
      check_batch_recorded! unless head == last_head
    end

    # The newest disposition of every finding from earlier batches, keyed by the id rounds share.
    # Rounds on `head` are left out, so reviewers of one commit do not see each other's findings.
    def prior_findings(head = nil)
      rounds.each_with_index.with_object({}) do |(round, index), latest|
        next if round['head'] == head

        LocalReviewFinding.list(round['findings'], "round #{index + 1} finding").each do |finding|
          latest[finding.id] = finding
        end
      end.values
    end

    # Reviewers of one commit run at once, so each append rereads the ledger under a lock and
    # checks again that the round still joins the last commit or starts a new one.
    def append!(base:, round:)
      locked do
        check_new_head!(round['head'], round['reviewer']) if rounds.any?
        write(data.merge('base' => base, 'rounds' => rounds + [round]))
      end
    end

    # Sets one last-batch round's findings and any usage the host reported for it. A batch with
    # several reviewers needs `reviewer` to say whose round this is.
    def record!(content, reviewer: nil)
      raise Error, 'Record content must be an object.' unless content.is_a?(Hash)

      locked { replace_round(recorded_index(reviewer), content) }
    end

    private

    def data
      @data ||= if File.exist?(@path)
                  parsed = JSON.parse(File.read(@path, encoding: 'UTF-8'))
                  raise Error, "#{@path} is not a review ledger." unless
                    parsed.is_a?(Hash) && parsed['rounds'].is_a?(Array)

                  parsed
                else
                  { 'rounds' => [] }
                end
    end

    def replace_round(index, content)
      round = rounds[index].merge(content.slice('findings', 'model', 'tokens', 'cost', 'estimate'))
      check_findings!(round, index + 1)
      write(data.merge(content.slice('fallback'), 'rounds' => rounds.dup.tap { |all| all[index] = round }))
    end

    def check_batch_recorded!
      unrecorded = batch.find { |index| !recorded?(rounds[index]) }
      raise Error, "Record round #{unrecorded + 1}'s findings with `shaka review record` before the next round." if
        unrecorded
    end

    # Indexes of the rounds that reviewed the last head.
    def batch = rounds.each_index.select { |index| rounds[index]['head'] == last_head }

    def recorded_index(reviewer, candidates = batch)
      raise Error, 'The ledger has no round to record.' if candidates.empty?
      return candidates.last if reviewer.nil? && candidates.one?
      raise Error, "Several reviewers read #{last_head}; pass --reviewer to record one." if reviewer.nil?

      candidates.find { |index| same_reviewer?(rounds[index], reviewer) } ||
        raise(Error, "No round by #{reviewer} reviewed #{last_head}.")
    end

    # Another reviewer may join the last batch; any other repeat of a commit needs a fix first.
    def check_new_head!(head, reviewer)
      reviewed = rounds.index { |round| round['head'] == head && !joins?(round, head, reviewer) }
      raise Error, "Round #{reviewed + 1} already reviewed #{head}; commit the fix first." if reviewed
    end

    def joins?(round, head, reviewer) = head == last_head && !same_reviewer?(round, reviewer)

    def same_reviewer?(round, reviewer) = round['reviewer'].to_s.casecmp?(reviewer.to_s)

    def locked
      File.open("#{@path}.lock", File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        @data = nil
        yield
      end
    end

    def recorded?(round) = round.key?('findings') || reported_count(round).zero?

    # The count check keeps a finding from dropping out between the report and the comment.
    def check_findings!(round, number)
      findings = LocalReviewFinding.list(round['findings'], "round #{number} finding")
      reported = reported_count(round)
      return if findings.size == reported

      raise Error, "Round #{number}'s report counts #{reported} findings; #{findings.size} were recorded."
    end

    def reported_count(round)
      match = File.read(round.fetch('report'), encoding: 'UTF-8').match(LocalReviewEvidence::CLOSING)
      raise Error, "Round report #{round['report']} has no FINDINGS count." unless match

      match[2].to_i
    end

    def write(content)
      temporary = "#{@path}.#{Process.pid}.tmp"
      File.write(temporary, "#{JSON.pretty_generate(content)}\n", perm: 0o600)
      File.rename(temporary, @path)
      @data = content
    end
  end
end

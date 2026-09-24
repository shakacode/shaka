# frozen_string_literal: true

require_relative 'error'

module Shaka
  # Finds the published local-review attestation an agent-driven merge relies on.
  #
  # A comment proves that this merging account published an attestation line for a commit. It
  # does not prove a reviewer process ran, which model answered, or that findings were fixed;
  # the result reports what the line claims so the record does not overstate it.
  class MergeReviewEvidence
    ATTESTATION = %r{^REVIEWED ([0-9a-f]{40}) BY ([a-z0-9._-]+/[a-z0-9._-]+) EFFORT (\S+) FINDINGS (\d+)[ \t]*\r?$}
    # GitHub's compare API lists at most this many files, so a full page may hide code changes.
    COMPARE_FILE_LIMIT = 300
    # Bounds compare requests when many earlier revisions were reviewed.
    EARLIER_CANDIDATES = 5

    def initialize(github, required:, waiver: nil)
      @github = github
      @required = required
      @waiver = waiver
    end

    def call(head)
      return { 'basis' => 'not_required' } if @required == 'none'

      reason = waiver_reason
      found = attestations
      current = found.find { |entry| entry['reviewed'] == head }
      return current.merge('basis' => 'current_head') if current

      rejected = []
      earlier = earlier_evidence(found, head, rejected)
      return earlier if earlier
      return { 'basis' => 'waived', 'reason' => reason } if reason

      raise Error, refusal(head, rejected)
    end

    private

    def waiver_reason
      return if @waiver.nil?

      reason = @waiver.to_s.strip
      raise Error, '--review-waiver needs a reason' if reason.empty?

      reason
    end

    # Newest first, so the latest review of a revision is the one reported.
    def attestations
      account = @github.viewer_login
      @github.issue_comments.reverse.flat_map do |comment|
        next [] unless comment.is_a?(Hash) && comment.dig('user', 'login') == account

        comment['body'].to_s.scan(ATTESTATION).reverse.map do |sha, reviewer, effort, findings|
          { 'reviewed' => sha, 'reviewer' => reviewer, 'effort' => effort,
            'findings' => findings.to_i, 'comment' => comment['html_url'] }.compact
        end
      end
    end

    def earlier_evidence(found, head, rejected)
      found.uniq { |entry| entry['reviewed'] }.first(EARLIER_CANDIDATES).each do |entry|
        changed = markdown_only_changes(entry['reviewed'], head, rejected)
        next unless changed

        return entry.merge('basis' => 'markdown_only_since_review', 'changed_since_review' => changed)
      end
      nil
    end

    def markdown_only_changes(reviewed, head, rejected)
      comparison = @github.compare(reviewed, head)
      problem = comparison_problem(comparison)
      return comparison['files'].map { |file| file['filename'] } unless problem

      rejected << "#{reviewed}: #{problem}"
      nil
    rescue Error => e
      rejected << "#{reviewed}: comparison unavailable (#{e.message})"
      nil
    end

    def comparison_problem(comparison)
      return 'it is not an ancestor of the head' unless comparison.is_a?(Hash) && comparison['status'] == 'ahead'

      files = comparison['files']
      return 'the file list is missing' unless files.is_a?(Array) && files.all?(Hash)
      return 'the file list may be truncated' if files.length >= COMPARE_FILE_LIMIT

      code = non_markdown_paths(files)
      "non-Markdown changes since review: #{code.first(3).join(', ')}" unless code.empty?
    end

    # A rename counts from both sides, so moving code into a .md name is still a code change.
    def non_markdown_paths(files)
      files.flat_map { |file| file.values_at('filename', 'previous_filename').compact }
           .reject { |path| markdown?(path) }.uniq
    end

    def markdown?(path) = path.is_a?(String) && path.downcase.end_with?('.md')

    def refusal(head, rejected)
      detail = if rejected.empty?
                 "No local-review attestation for #{head} was published on this PR by the merging account."
               else
                 "No local-review attestation covers #{head}; earlier attestations do not apply: " \
                   "#{rejected.join('; ')}."
               end
      "#{detail} Publish the review report with its closing `REVIEWED <head> BY <provider>/<family> " \
        'EFFORT <effort> FINDINGS <n>` line, or pass --review-waiver REASON when review was ' \
        'intentionally skipped or a CI review covered this head.'
    end
  end
end

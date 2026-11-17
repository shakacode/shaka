# frozen_string_literal: true

# Loaded by history.rb after LocalReviewHistory is defined.
module Shaka
  # Folds the local review comments an agent selects behind the one it names as current, such as an
  # earlier ledger's comment once a base change forced a new ledger. Publication leaves another
  # ledger's report visible because Ruby cannot tell whether its findings were carried forward.
  class SelectedLocalReviewHistory < LocalReviewHistory
    NOT_FOLDED = "was not folded: select this account's local review comments on this pull request " \
                 'that review a different commit than the current one.'

    # A current comment that is not a local review report selects evidence comments instead.
    def self.collapse(github, superseded, current)
      body = github.api("repos/#{github.repository}/issues/comments/#{current}")['body'].to_s
      return EvidenceHistory.new(github).collapse(superseded, current:) unless body.match?(KEY)

      new(github, ids: [*superseded, current], current:).collapse_selection(superseded)
    rescue Error => e
      { 'collapsed' => [], 'unavailable' => ["Comment #{current}: #{e.message}"] }
    end

    def initialize(github, ids:, current:)
      super(github, ids:)
      @current = current
    end

    # Lists every selected comment left unfolded; one that already links the current one counts as folded.
    def collapse_selection(superseded)
      report = collapse
      reported = reported(report)
      return report if reported.include?(@current)

      missed = superseded - report['collapsed'] - reported - linked(superseded, report)
      report.merge('unavailable' => report['unavailable'] + missed.map { |id| "Comment #{id} #{NOT_FOLDED}" })
    end

    private

    def reported(report) = report['unavailable'].filter_map { |line| line[/\AComment (\d+):/, 1]&.to_i }

    def latest_comment(comments)
      head_reports(comments).find { |comment| comment['id'] == @current } ||
        raise(Error, "Comment #{@current}: Current comment is not this account's visible local review " \
                     'of the pull request head here.')
    end

    # Unlike automatic cleanup, an archived report of the current commit stays where it points.
    def earlier?(comment, latest) = attestation(comment['body'])[1] != attestation(latest['body'])[1]

    # A refused renderer folded nothing, so no selection counts as already linked.
    def linked(ids, report)
      return [] if report['skipped']

      pointer = "#{MARKER} #{url_prefix}#{@current}\n"
      @github.issue_comments.filter_map do |comment|
        comment['id'] if ids.include?(comment['id']) && owned?(comment) && comment['body'].include?(pointer)
      end
    rescue Error => e
      report['unavailable'] << "Folded comments could not be listed again: #{e.message}"
      []
    end
  end
end

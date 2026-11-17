# frozen_string_literal: true

# Loaded by history.rb after LocalReviewHistory is defined.
module Shaka
  # Folds the local review comments an agent selects behind the one it names as current, such as an
  # earlier ledger's comment once a base change forced a new ledger. Publication leaves another
  # ledger's report visible because Ruby cannot tell whether its findings were carried forward.
  class SelectedLocalReviewHistory < LocalReviewHistory
    NOT_FOLDED = "was not folded: select this account's local review comments on this pull request " \
                 'that review an earlier commit than the current one.'

    # A current comment that is not a local review report selects evidence comments instead.
    def self.collapse(github, superseded, current)
      body = github.api("repos/#{github.repository}/issues/comments/#{current}")['body'].to_s
      return EvidenceHistory.new(github).collapse(superseded, current:) unless body.match?(KEY)

      report = new(github, ids: [*superseded, current], current:).collapse
      return report unless report['unavailable'].empty?

      report.merge('unavailable' => (superseded - report['collapsed']).map { |id| "Comment #{id} #{NOT_FOLDED}" })
    rescue Error => e
      { 'collapsed' => [], 'unavailable' => ["Comment #{current}: #{e.message}"] }
    end

    def initialize(github, ids:, current:)
      super(github, ids:)
      @current = current
    end

    private

    def latest_comment(comments)
      head_reports(comments).find { |comment| comment['id'] == @current } ||
        raise(Error, "Comment #{@current}: Current comment is not this account's visible local review " \
                     'of the pull request head here.')
    end
  end
end

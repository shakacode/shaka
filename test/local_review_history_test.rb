# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/github'
require 'shaka/local_review'

module LocalReviewHistoryFixture
  HEAD = 'a' * 40
  PRIOR = 'b' * 40
  ATTESTATION = "REVIEWED #{PRIOR} BY anthropic/claude EFFORT medium FINDINGS 1".freeze

  class GitHub < Shaka::GitHub
    attr_reader :comments, :writes
    attr_accessor :failure, :changed, :mismatched, :listing, :head

    def initialize(comments)
      super('example/test', '1')
      @comments = comments.to_h { |comment| [comment['id'], comment] }
      @writes = []
      @reads = Hash.new(0)
      @head = HEAD
    end

    def viewer_login = 'ada'
    def issue_comments = listing || comments.values
    def verify_rendering(_body) = '<p>Rendered.</p>'

    def api(path, method: 'GET', fields: {})
      return { 'head' => { 'sha' => head } } if path.end_with?('/pulls/1')

      id = path.split('/').last.to_i
      row = comments.fetch(id)
      method == 'PATCH' ? update(id, row, fields.fetch(:body)) : read(id, row)
      row.dup
    end

    def update(id, row, body)
      raise Shaka::Error, 'Update failed' if failure

      @writes << [id, body]
      row['body'] = body unless mismatched
    end

    def read(id, row)
      @reads[id] += 1
      row['body'] += "\nHuman edit" if changed && @reads[id] == 2
    end
  end

  def republish_previous_head(github)
    github.head = HEAD
    github.comments[2]['body'] = comment(2, head: HEAD)['body']
    collapse(github, github.comments[2])
  end

  def replace_after_listing(github)
    github.listing = github.comments.values.map(&:dup)
    github.comments[1]['body'] = comment(1, head: HEAD)['body']
  end

  def add_new_review(github)
    github.head = 'c' * 40
    github.comments[3] = comment(3, head: github.head)
    collapse(github, github.comments[3])
  end

  def prepared_history
    github = GitHub.new([comment(1), comment(2, head: HEAD)])
    collapse(github, github.comments[2])
    github
  end

  def assert_archived(body, latest)
    assert_includes body, url(latest)
    assert_includes body, 'Documented risk: still inspect the retained parser.'
    assert_includes body, '<summary>Earlier local review</summary>'
    assert_equal 1, body.scan('<details>').size
    assert_equal ATTESTATION, body.lines.last.strip
  end

  def collapse(github, published) = Shaka::LocalReviewHistory.new(github).collapse(published)

  def url(id) = "https://github.com/example/test/pull/1#issuecomment-#{id}"

  def comment(id, head: PRIOR, login: 'ada', key: "local-review-#{head}")
    body = "<!-- shaka:reply:#{key} -->\n# Local Adversarial Review\n\n" \
           "Documented risk: still inspect the retained parser.\n\n" \
           "REVIEWED #{head} BY anthropic/claude EFFORT medium FINDINGS 1\n"
    { 'id' => id, 'created_at' => '2026-10-01T00:00:00Z', 'user' => { 'login' => login }, 'body' => body }
  end
end

class LocalReviewHistoryTest < Minitest::Test
  include LocalReviewHistoryFixture

  def test_collapses_older_owned_reports_without_losing_findings_or_merge_evidence
    prior = comment(1)
    latest = comment(2, head: HEAD)
    github = GitHub.new([prior, latest, comment(3, login: 'someone-else'),
                         comment(4).merge('body' => 'Human discussion')])
    result = collapse(github, latest)

    assert_equal [1], result['collapsed']
    assert_empty result['unavailable']
    assert_archived(prior['body'], 2)
    refute_includes latest['body'], 'Earlier local review'
  end

  def test_supports_the_legacy_comment_key
    prior = comment(1, key: 'local-adversarial-review')
    latest = comment(2, head: HEAD)
    assert_equal [1], collapse(GitHub.new([prior, latest]), latest)['collapsed']
  end

  def test_retargets_existing_history_without_nesting_or_losing_annotations
    github = prepared_history
    prior = github.comments[1]
    prior['body'] = prior['body'].sub("\n\n</details>", "\nHuman annotation\n\n</details>")
    add_new_review(github)

    assert_includes prior['body'], 'Human annotation'
    assert_archived(prior['body'], 3)
    assert_empty collapse(github, github.comments[3])['collapsed']
  end

  def test_foreign_keys_unattested_reports_and_same_commit_reports_stay_intact
    prior = comment(1).merge('body' => "<!-- shaka:reply:human-note -->\n#{ATTESTATION}")
    invalid = comment(2).merge('body' => "<!-- shaka:reply:local-review-#{PRIOR} -->\nHuman note")
    same = comment(3, head: HEAD)
    latest = comment(4, head: HEAD)
    github = GitHub.new([prior, invalid, same, latest])

    assert_empty collapse(github, latest)['collapsed']
    assert_empty github.writes
  end

  def test_failed_changed_or_unconfirmed_writes_report_the_gap
    %i[failure changed mismatched].each do |problem|
      latest = comment(2, head: HEAD)
      github = GitHub.new([comment(1), latest])
      github.public_send("#{problem}=", true)
      result = collapse(github, latest)
      assert_empty result['collapsed']
      refute_empty result['unavailable']
      assert_empty github.writes if problem == :changed
    end
  end

  def test_no_current_head_review_leaves_every_report_intact
    prior = comment(1)
    github = GitHub.new([prior])
    result = collapse(github, prior)

    assert_empty result['collapsed']
    assert_empty result['unavailable']
    assert_includes result['skipped'], 'left intact'
    assert_empty github.writes
  end

  def test_republishing_an_old_report_keeps_the_current_head_target
    github = prepared_history
    result = collapse(github, github.comments[1])

    assert_empty result['collapsed']
    assert_includes github.comments[1]['body'], url(2)
    refute_includes github.comments[2]['body'], 'Earlier local review'
  end

  def test_returning_to_an_earlier_head_retargets_history_and_collapses_later_reports
    github = prepared_history
    add_new_review(github)
    republish_previous_head(github)

    assert_archived(github.comments[1]['body'], 2)
    assert_includes github.comments[3]['body'], url(2)
  end

  def test_returned_head_without_republication_keeps_history_intact
    github = prepared_history
    add_new_review(github)
    github.head = HEAD

    assert_includes collapse(github, github.comments[2])['skipped'], 'left intact'
  end

  def test_quoting_the_history_marker_inside_a_current_report_does_not_archive_it
    prior = comment(1)
    latest = comment(2, head: HEAD)
    quoted = "#{Shaka::LocalReviewHistory::MARKER} example\nDocumented risk:"
    latest['body'] = latest['body'].sub('Documented risk:', quoted)

    assert_equal [1], collapse(GitHub.new([prior, latest]), latest)['collapsed']
  end

  def test_a_report_that_changed_to_the_current_head_before_first_read_is_not_collapsed
    github = GitHub.new([comment(1), comment(2, head: HEAD)])
    replace_after_listing(github)

    assert_empty collapse(github, github.comments[2])['collapsed']
  end

  def test_nested_details_preserve_report_text_without_closing_the_archive
    prior = comment(1)
    nested = '<details><summary>Report</summary>Kept</details> Documented risk:'
    prior['body'] = prior['body'].sub('Documented risk:', nested)
    latest = comment(2, head: HEAD)
    collapse(GitHub.new([prior, latest]), latest)

    assert_equal 1, prior['body'].scan('<details>').size
    assert_includes prior['body'], '&lt;details&gt;<summary>Report</summary>Kept&lt;/details&gt;'
  end
end

class LocalReviewCollapseCommandTest < Minitest::Test
  include LocalReviewHistoryFixture

  def test_collapse_command_reports_confirmed_cleanup
    github = GitHub.new([comment(1), comment(2, head: HEAD)])
    out, = capture_io do
      assert_equal 0, Shaka::LocalReview.run(['collapse', 'example/test', '1'], github:)
    end
    assert_equal [1], JSON.parse(out)['collapsed']
  end

  def test_collapse_command_returns_nonzero_for_failed_cleanup
    github = GitHub.new([comment(1), comment(2, head: HEAD)])
    github.failure = true
    out, = capture_io do
      assert_equal 1, Shaka::LocalReview.run(['collapse', 'example/test', '1'], github:)
    end
    assert_includes JSON.parse(out)['unavailable'].join, 'Update failed'
  end
end

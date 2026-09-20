# frozen_string_literal: true

require_relative 'github_helper'

# Neither renderer holds both bodies, so each surface fetches its published sibling.
class GitHubWritingTest < Minitest::Test
  include GitHubHelper

  COPIED = 'The loader now rejects an unknown review mode before the workflow starts.'
  REVIEW_URL = 'https://github.com/owner/repo/pull/42#pullrequestreview-123'
  SUMMARY = "🤖 Claude · Anthropic · opus 5 · medium\n\n#{COPIED} Maintainers merge without the diff.\n".freeze

  def pull_body(body) = response({ 'id' => 1, 'number' => 42, 'body' => body })

  def managed(body) = pull_body("<!-- shaka:begin -->\n#{body}<!-- shaka:end -->")

  def walkthrough_body = "#{SUMMARY}\n#{WALKTHROUGH}"

  def test_description_repeating_its_linked_walkthrough_is_refused_before_any_write
    body = "#{SUMMARY}\n## Code Walkthrough\n\n[Code Walkthrough](#{REVIEW_URL})\n"
    github = client(pull_body('old'), review_response(body: "#{COPIED} ReviewSchema raises while loading."))
    error = assert_raises(Shaka::Error) { github.description(body: body) }
    assert_includes error.message, 'This description repeats'
    assert_equal 2, @calls.size
  end

  def publishes(body)
    merged = "<!-- shaka:begin -->\n#{body}<!-- shaka:end -->"
    github = client(pull_body(''), html_response('<p>ok</p>'), pull_body(''), pull_body(merged))
    github.description(body: body)
    refute_includes @calls.map { |argv, _| argv.join(' ') }.join("\n"), '/reviews/'
  end

  # Publishing the first description links no review, so nothing is fetched or compared.
  def test_a_description_without_a_published_walkthrough_reads_no_review
    publishes("#{SUMMARY}\n## Code Walkthrough\n\n_Not published yet._\n")
  end

  # A review URL for another pull request is not this description's sibling.
  def test_a_foreign_review_link_is_not_treated_as_the_sibling
    foreign = 'https://github.com/owner/repo/pull/99#pullrequestreview-123'
    publishes("#{SUMMARY}\n## Code Walkthrough\n\n[Code Walkthrough](#{foreign})\n")
  end

  # A review that cannot be read leaves the comparison unmade rather than blocking the PR.
  def test_an_unreadable_walkthrough_skips_the_comparison_instead_of_refusing
    body = "#{SUMMARY}\n## Code Walkthrough\n\n[Code Walkthrough](#{REVIEW_URL})\n"
    merged = "<!-- shaka:begin -->\n#{body}<!-- shaka:end -->"
    github = client(pull_body(''), response({ 'message' => 'gone' }, status: 1), html_response('<p>ok</p>'),
                    pull_body(''), pull_body(merged))
    _out, err = capture_subprocess_io { github.description(body: body) }
    assert_includes err, 'duplication check skipped'
  end

  def test_walkthrough_repeating_the_published_description_is_refused_before_its_evidence
    github = client(snapshot_response, managed("#{COPIED} Maintainers merge without the diff.\n"))
    error = assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: walkthrough_body) }
    assert_includes error.message, 'This walkthrough repeats'
    assert_equal 2, @calls.size
  end

  def test_a_walkthrough_published_before_any_description_is_not_compared
    github = client(snapshot_response, pull_body(''), files_response, *gate_responses, html_response,
                    review_response(body: walkthrough_body), review_response(body: walkthrough_body),
                    snapshot_response)
    assert_equal 123, github.walkthrough(head: HEAD, body: walkthrough_body)['id']
  end

  # Another bot's summary in the same body is not this writer's prose to answer for.
  def test_only_the_managed_region_of_the_description_is_compared
    outside = pull_body("#{COPIED} Maintainers merge without the diff.\n\n<!-- shaka:begin -->\nOther.\n" \
                        '<!-- shaka:end -->')
    github = client(snapshot_response, outside, files_response, *gate_responses, html_response,
                    review_response(body: walkthrough_body), review_response(body: walkthrough_body),
                    snapshot_response)
    assert_equal 123, github.walkthrough(head: HEAD, body: walkthrough_body)['id']
  end
end

# frozen_string_literal: true

require_relative 'github_helper'

class GitHubWalkthroughEvidenceTest < Minitest::Test
  include GitHubHelper

  # Catches a walkthrough that names no blob URL at the head for a changed path.
  def test_walkthrough_without_a_commit_pinned_changed_file_link_is_refused
    github = client(snapshot_response, files_response)
    error = assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: 'A walkthrough.') }
    assert_includes error.message, 'commit-pinned'
    assert_equal 2, @calls.size
  end

  # Catches a blob link that points at the head but not at a path in the diff.
  def test_walkthrough_pin_to_an_unchanged_path_is_refused
    github = client(snapshot_response, files_response)
    body = "See https://github.com/owner/repo/blob/#{HEAD}/README.md."
    error = assert_raises(Shaka::Error) { github.walkthrough(head: HEAD, body: body) }
    assert_includes error.message, 'commit-pinned'
    assert_equal 2, @calls.size
  end

  def test_walkthrough_pin_to_a_renamed_file_previous_path_is_accepted
    files = response([{ 'filename' => 'new.yml', 'previous_filename' => CHANGED_FILE }])
    github = client(snapshot_response, files, *gate_responses, html_response, review_response, review_response,
                    snapshot_response)
    published = github.walkthrough(head: HEAD, body: WALKTHROUGH)
    assert_equal 'COMMENTED', published['state']
  end

  # Catches a walkthrough that omits a completed review check visible on the PR.
  def test_walkthrough_omitting_a_completed_review_gate_is_refused
    github = client(snapshot_response, files_response, *gate_responses)
    error = assert_raises(Shaka::Error) do
      github.walkthrough(head: HEAD, body: "See #{PINNED_LINK}. Gates: validate.")
    end
    assert_includes error.message, 'claude-review'
    refute_includes error.message, 'validate'
    assert_equal 4, @calls.size
  end

  # Catches a required check that finished and is missing from the walkthrough.
  def test_walkthrough_omitting_a_completed_required_check_is_refused
    github = client(snapshot_response, files_response, *gate_responses)
    error = assert_raises(Shaka::Error) do
      github.walkthrough(head: HEAD, body: "See #{PINNED_LINK}. Gates: claude-review.")
    end
    assert_includes error.message, 'validate'
    assert_equal 4, @calls.size
  end

  def test_pending_review_checks_are_not_required_in_the_walkthrough
    body = "See #{PINNED_LINK}. Gates: validate."
    github = client(snapshot_response, files_response, *pending_review_gate_responses, html_response,
                    review_response(body: body), review_response(body: body), snapshot_response)
    assert_equal 'COMMENTED', github.walkthrough(head: HEAD, body: body)['state']
  end
end

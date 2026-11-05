# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/provenance'

class TaskSourceLineTest < Minitest::Test
  PUBLIC_PROVENANCE = { 'task_source' => 'description', 'initial_prompt' => 'EXCLUDED',
                        'requested_model' => nil, 'requested_effort' => nil,
                        'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
                        'active_model' => 'gpt-5.6-terra', 'active_effort' => 'medium' }.freeze
  ISSUE = PUBLIC_PROVENANCE.merge('task_source' => 'issue', 'task_number' => 1234).freeze
  LINEAR = PUBLIC_PROVENANCE.merge('task_source' => 'issue', 'task_tracker' => 'linear',
                                   'task_key' => 'MKT-1234').freeze

  def test_a_prompt_is_named_after_the_agent_that_took_it
    assert_equal '**Task:** Claude prompt', line(PUBLIC_PROVENANCE, 'Claude Code')
    assert_equal '**Task:** Codex prompt', line(PUBLIC_PROVENANCE, 'Codex')
    assert_equal '**Task:** Claude prompt', line(PUBLIC_PROVENANCE, 'claude')
    assert_equal '**Task:** task description', line(PUBLIC_PROVENANCE, nil)
  end

  def test_a_github_task_names_its_number_and_relation
    assert_equal '**Task:** GitHub #1234', line(ISSUE)
    assert_equal '**Task:** GitHub #1234 · part of', line(ISSUE.merge('task_relation' => 'part_of'))
    assert_equal '**Task:** GitHub #1234 · related', line(ISSUE.merge('task_relation' => 'refs'))
    pull = ISSUE.merge('task_source' => 'pull_request', 'task_relation' => 'follow_up')
    assert_equal '**Task:** GitHub PR #1234 · follow-up', line(pull)
  end

  # GitHub closes the issue only when the keyword directly precedes the bare reference.
  def test_a_fix_puts_its_closing_keyword_before_the_number
    assert_equal '**Task:** GitHub · fixes #1234', line(ISSUE.merge('task_relation' => 'fixes'))
  end

  def test_another_trackers_ticket_is_linked_when_a_url_is_supplied
    linear = LINEAR.merge('task_url' => 'https://linear.app/example/issue/MKT-1234')
    assert_equal '**Task:** [Linear MKT-1234](https://linear.app/example/issue/MKT-1234)', line(linear)
    jira = LINEAR.merge('task_tracker' => 'jira', 'task_key' => 'PROJ-1234',
                        'task_url' => 'https://acme.atlassian.net/browse/PROJ-1234', 'task_relation' => 'part_of')
    assert_equal '**Task:** [Jira PROJ-1234](https://acme.atlassian.net/browse/PROJ-1234) · part of', line(jira)
  end

  def test_refuses_a_ticket_without_a_url_or_an_omission_reason
    error = assert_raises(Shaka::Error) { line(LINEAR) }

    assert_includes error.message, 'task_url'
    assert_includes error.message, 'task_url_omission_reason'
  end

  def test_an_unlinked_ticket_explains_why_its_url_was_omitted
    assert_equal '**Task:** Linear MKT-1234 · URL omitted: Tracker access unavailable.',
                 line(LINEAR.merge('task_url_omission_reason' => 'Tracker access unavailable.'))
    assert_equal '**Task:** Linear MKT-1234 · URL omitted: Private task URL cannot be shared.',
                 line(LINEAR.merge('task_url_omission_reason' => 'Private task URL cannot be shared.'))
  end

  def test_a_task_in_another_repository_can_link_its_url_without_a_local_number
    %w[issue pull_request].each do |source|
      spec = PUBLIC_PROVENANCE.merge('task_source' => source, 'task_url' => 'https://github.com/other/repo/issues/1')
      assert_equal "**Task:** [#{source.tr('_', ' ')}](https://github.com/other/repo/issues/1)", line(spec)
    end
  end

  def test_a_private_task_can_withhold_its_key_and_url_with_an_explicit_reason
    %w[issue pull_request].each do |source|
      spec = PUBLIC_PROVENANCE.merge('task_source' => source, 'task_url_omission_reason' => 'Private task.')
      assert_equal "**Task:** #{source.tr('_', ' ')} · URL omitted: Private task.", line(spec)
      assert_raises(Shaka::Error) { line(spec.except('task_url_omission_reason')) }
    end
  end

  def test_refuses_empty_or_multiline_omission_reasons
    [nil, false, 42, {}, [], '', '   ', "\t", "Unavailable.\nNext line", "Private.\rNext line"].each do |reason|
      assert_raises(Shaka::Error, reason.inspect) { line(LINEAR.merge('task_url_omission_reason' => reason)) }
    end
  end

  def test_refuses_both_a_url_and_an_omission_reason
    spec = LINEAR.merge('task_url' => 'https://linear.app/example/issue/MKT-1234',
                        'task_url_omission_reason' => 'Unavailable.')
    assert_raises(Shaka::Error) { line(spec) }
  end

  def test_prompt_and_numbered_tasks_cannot_override_their_automatic_task_reference
    [PUBLIC_PROVENANCE, ISSUE].each do |spec|
      assert_raises(Shaka::Error) { line(spec.merge('task_url' => 'https://example.com/task')) }
      assert_raises(Shaka::Error) { line(spec.merge('task_url_omission_reason' => 'Private.')) }
    end
  end

  def test_refuses_a_relation_or_tracker_it_cannot_render_safely
    invalid = [ISSUE.merge('task_relation' => 'closes'), PUBLIC_PROVENANCE.merge('task_relation' => 'refs'),
               ISSUE.merge('task_source' => 'pull_request', 'task_relation' => 'fixes'),
               LINEAR.merge('task_relation' => 'fixes'), LINEAR.merge('task_tracker' => 'trello'),
               LINEAR.merge('task_key' => 'mkt 1234'), LINEAR.merge('task_number' => 1234),
               LINEAR.merge('task_url' => 'http://linear.app/x'), LINEAR.merge('task_url' => 'https://x.test/a)(b')]
    invalid.each do |spec|
      assert_raises(Shaka::Error, spec.inspect) { line(spec) }
    end
  end

  private

  def line(spec, agent = 'Claude Code') = Shaka::ExecutionProvenance.new(spec).line(agent)
end

class TaskUrlSafetyTest < Minitest::Test
  LINEAR = TaskSourceLineTest::LINEAR

  def test_a_ticket_url_may_carry_a_query_and_fragment
    url = 'https://acme.atlassian.net/browse/PROJ-1234?focusedCommentId=1#comment-1'
    jira = LINEAR.merge('task_tracker' => 'jira', 'task_key' => 'PROJ-1234', 'task_url' => url)

    assert_equal "**Task:** [Jira PROJ-1234](#{url})", line(jira)
  end

  def test_refuses_a_ticket_url_with_a_backslash_or_no_host
    ['https://x.test/a\\', 'https:///x', 'https://:443/task', 'https://a@:443/task', 'https://a@/task',
     'https://user@x.test/a'].each do |url|
      assert_raises(Shaka::Error, url) { line(LINEAR.merge('task_url' => url)) }
    end
  end

  def test_refuses_a_ticket_url_with_an_invalid_port
    ['https://example.com:abc/task', 'https://example.com:65536/task', 'https://example.com:-1/task'].each do |url|
      assert_raises(Shaka::Error, url) { line(LINEAR.merge('task_url' => url)) }
    end
  end

  def test_a_ticket_url_may_use_a_valid_explicit_port
    url = 'https://example.com:8443/task'
    assert_equal "**Task:** [Linear MKT-1234](#{url})", line(LINEAR.merge('task_url' => url))
  end

  private

  def line(spec) = Shaka::ExecutionProvenance.new(spec).line('Claude Code')
end

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

  def test_another_trackers_ticket_is_linked_only_when_a_url_is_supplied
    assert_equal '**Task:** Linear MKT-1234', line(LINEAR)
    jira = LINEAR.merge('task_tracker' => 'jira', 'task_key' => 'PROJ-1234',
                        'task_url' => 'https://acme.atlassian.net/browse/PROJ-1234', 'task_relation' => 'part_of')
    assert_equal '**Task:** [Jira PROJ-1234](https://acme.atlassian.net/browse/PROJ-1234) · part of', line(jira)
  end

  def test_a_task_in_another_github_repository_names_only_its_kind
    assert_equal '**Task:** issue', line(PUBLIC_PROVENANCE.merge('task_source' => 'issue'))
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

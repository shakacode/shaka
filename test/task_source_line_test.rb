# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/publication/provenance'

class TaskSourceLineTest < Minitest::Test
  PUBLIC_PROVENANCE = { 'task_source' => 'description', 'initial_prompt' => 'EXCLUDED',
                        'requested_model' => nil, 'requested_effort' => nil,
                        'recommended_model' => 'gpt-5.6-terra', 'recommended_effort' => 'medium',
                        'active_model' => 'gpt-5.6-terra', 'active_effort' => 'medium' }.freeze
  PULL = { 'base' => { 'repo' => { 'full_name' => 'shakacode/shaka' } } }.freeze

  def test_the_task_source_line_names_how_the_pull_request_relates_to_its_task
    issue = PUBLIC_PROVENANCE.merge('task_source' => 'issue', 'task_number' => 818)
    { 'fixes' => 'Fixes #818', 'part_of' => 'Part of #818', 'follow_up' => 'Follow-up to #818',
      'refs' => 'Refs #818' }.each do |relation, text|
      line = Shaka::ExecutionProvenance.new(issue.merge('task_relation' => relation), pull: PULL).line

      assert_equal "**Task source:** #{text}", line
    end
  end

  def test_without_a_relation_the_line_names_the_task_alone
    issue = PUBLIC_PROVENANCE.merge('task_source' => 'issue', 'task_number' => 818)
    pull = issue.merge('task_source' => 'pull_request')

    assert_equal '**Task source:** issue #818', Shaka::ExecutionProvenance.new(issue, pull: PULL).line
    assert_equal '**Task source:** task description', Shaka::ExecutionProvenance.new(PUBLIC_PROVENANCE).line
    assert_equal '**Task source:** pull request #818', Shaka::ExecutionProvenance.new(pull).line
    assert_equal '**Task source:** Follow-up to #818',
                 Shaka::ExecutionProvenance.new(pull.merge('task_relation' => 'follow_up')).line
  end

  def test_refuses_a_task_relation_without_a_task_it_can_name
    issue = PUBLIC_PROVENANCE.merge('task_source' => 'issue', 'task_number' => 818)
    invalid = [issue.merge('task_relation' => 'closes'), PUBLIC_PROVENANCE.merge('task_relation' => 'refs'),
               issue.merge('task_source' => 'pull_request', 'task_relation' => 'fixes')]
    invalid.each do |spec|
      error = assert_raises(Shaka::Error) { Shaka::ExecutionProvenance.new(spec).line }

      assert_includes error.message, 'task_relation'
    end
  end
end

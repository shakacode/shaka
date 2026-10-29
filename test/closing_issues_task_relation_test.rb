# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'closing_issues_test'

# The Task line's relation tells the closing-issue note whether the task's issue should close.
class ClosingIssuesTaskRelationTest < Minitest::Test
  FakeGitHub = ClosingIssuesTest::FakeGitHub

  # A fixes task relation renders `fixes #N` in the Task line, so the note checks it like summary text.
  def test_a_fixes_task_relation_is_checked_like_summary_text
    data = content('A neutral summary.').merge('provenance' => { 'task_source' => 'issue', 'task_number' => 818,
                                                                 'task_relation' => 'fixes' })
    note = Shaka::ClosingIssues.note(data, FakeGitHub.new([]))['closing_issues']

    assert_includes note, 'fixes #818, but GitHub will not close it'
    assert_equal({}, Shaka::ClosingIssues.note(data, FakeGitHub.new(['owner/repo#818'])))
    part = data.merge('provenance' => data['provenance'].merge('task_relation' => 'part_of'))
    assert_equal({}, Shaka::ClosingIssues.note(part, FakeGitHub.new([])))
  end

  # task_relation describes only the task's issue, so another unlinked claim keeps the prose advice.
  def test_only_the_task_issue_is_pointed_to_task_relation
    data = content('Fixes #5.', task: 9)
    data['provenance']['task_relation'] = 'part_of'
    note = Shaka::ClosingIssues.note(data, FakeGitHub.new([]))['closing_issues']

    assert_includes note, 'or use `Part of` when the issue stays open'
    refute_includes note, 'task_relation'
    task = data.merge('summary' => 'A neutral summary.')
    task['provenance'] = task['provenance'].merge('task_relation' => 'fixes')
    assert_includes Shaka::ClosingIssues.note(task, FakeGitHub.new([]))['closing_issues'], '`task_relation` `part_of`'
  end

  def test_a_mixed_list_gives_each_issue_its_own_advice
    data = content('Fixes #5.', task: 9)
    data['provenance']['task_relation'] = 'fixes'
    note = Shaka::ClosingIssues.note(data, FakeGitHub.new([]))['closing_issues']

    assert_includes note, "`task_relation` `part_of` for the task's issue and `Part of` for the others"
  end

  # A non-fixes relation renders "GitHub #631 · part of", which says the task's issue stays open.
  def test_a_partial_task_relation_leaves_the_task_issue_open_without_a_note
    %w[part_of follow_up refs].each do |relation|
      data = content('Adds the check.', task: 631)
      data['provenance']['task_relation'] = relation

      assert_equal({}, Shaka::ClosingIssues.note(data, FakeGitHub.new([])), relation)
    end
  end

  # A prose claim on the task's issue is corrected in prose, because task_relation would not remove it.
  def test_a_prose_claim_on_the_task_issue_keeps_the_prose_advice
    note = Shaka::ClosingIssues.note(content('Fixes #9.', task: 9), FakeGitHub.new([]))['closing_issues']

    assert_includes note, 'or use `Part of` when'
  end

  # Both the prose and the Task line claim the issue, so one correction must change both.
  def test_a_prose_claim_beside_a_fixes_relation_names_both_places
    data = content('Fixes #9.', task: 9)
    data['provenance']['task_relation'] = 'fixes'
    note = Shaka::ClosingIssues.note(data, FakeGitHub.new([]))['closing_issues']

    assert_includes note, 'or use `task_relation` `part_of` and `Part of` in the prose when'
  end

  # The merge handoff reads the published body, so a partial Task line must read as Part of there too.
  def test_the_handoff_reads_a_published_partial_task_line
    github = FakeGitHub.new([])
    body = "**Task:** GitHub #631 · part of\n\n| Task source | issue [#631](https://github.com/owner/repo/issues/631) |"

    assert_equal 'closes no issues', Shaka::ClosingIssues.fact(github, body)
    assert_equal 'closes no issues', Shaka::ClosingIssues.fact(github, body.gsub("\n", "\r\n"))
    assert_includes Shaka::ClosingIssues.fact(github, body.sub(' · part of', '')), 'task issue #631 stays open'
  end

  private

  def content(summary, task: nil)
    provenance = { 'task_source' => 'issue', 'task_number' => task } if task
    { 'summary' => summary, 'intent' => { 'why' => 'A problem.' }, 'provenance' => provenance }.compact
  end
end

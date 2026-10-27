# frozen_string_literal: true

require_relative 'test_helper'
require 'shaka/closing_issues'

# Proves the description note names each issue the text claims to fix that GitHub will not close.
class ClosingIssuesTest < Minitest::Test
  # Answers the closing-reference read with the issues GitHub linked, counting reads.
  class FakeGitHub
    attr_reader :repository, :number, :reads

    def initialize(linked, repository: 'owner/repo', total: nil)
      @linked = linked
      @total = total
      @repository = repository
      @number = 7
      @reads = 0
    end

    def graphql(_query, **)
      @reads += 1
      raise Shaka::Error, 'GraphQL failed or returned missing data.' if @linked == :unreadable

      nodes = @linked.map do |issue|
        repository, number = issue.split('#')
        { 'number' => Integer(number), 'repository' => { 'nameWithOwner' => repository } }
      end
      references = { 'totalCount' => @total || nodes.size, 'nodes' => nodes }
      { 'repository' => { 'pullRequest' => { 'closingIssuesReferences' => references } } }
    end
  end

  def test_a_second_issue_after_one_keyword_is_named
    note = note_for('Fixes #727 and #729.', ['owner/repo#727'])

    assert_includes note, 'fixes #729, but GitHub will not close it'
    refute_includes note, '#727,'
  end

  def test_matching_closing_references_add_no_note
    assert_equal({}, Shaka::ClosingIssues.note(content('Fixes #727, fixes #729.'),
                                               FakeGitHub.new(['owner/repo#727', 'owner/repo#729'])))
  end

  def test_a_reference_without_a_keyword_claims_nothing
    github = FakeGitHub.new([])

    ['Refs #763.', 'Part of #683.', 'This was fixed in #806.', 'Mentions #762 only.',
     'Warns when `Fixes #1 and #2` closes only #1.', 'Quotes ``Fixes #3`` too.'].each do |text|
      assert_equal({}, Shaka::ClosingIssues.note(content(text), github), text)
    end
  end

  def test_the_task_issue_left_open_without_a_keyword_is_named
    note = Shaka::ClosingIssues.note(content('Adds the check.', task: 631), FakeGitHub.new([]))['closing_issues']

    assert_includes note, "task's issue #631, but GitHub will not close it"
  end

  def test_part_of_the_task_issue_or_a_linked_task_issue_adds_no_note
    assert_equal({}, Shaka::ClosingIssues.note(content('Part of #631.', task: 631), FakeGitHub.new([])))
    assert_equal({}, Shaka::ClosingIssues.note(content('Adds the check.', task: 631),
                                               FakeGitHub.new(['owner/repo#631'])))
  end

  def test_a_claimed_task_issue_github_will_not_close_is_named_once
    note = Shaka::ClosingIssues.note(content('Fixes #1 and #631.', task: 631),
                                     FakeGitHub.new(['owner/repo#1']))['closing_issues']

    assert_includes note, 'fixes #631, but GitHub will not close it'
    refute_includes note, "task's issue"
  end

  def test_a_task_issue_the_text_calls_partial_but_github_closes_is_named
    note = Shaka::ClosingIssues.note(content('Part of #631.', task: 631),
                                     FakeGitHub.new(['owner/repo#631']))['closing_issues']

    assert_includes note, 'GitHub will also close #631'
  end

  def test_an_issue_neither_the_task_nor_the_text_names_is_named
    note = Shaka::ClosingIssues.note(content('Fixes #631.', task: 631),
                                     FakeGitHub.new(['owner/repo#631', 'other/lib#5']))['closing_issues']

    assert_includes note, 'GitHub will also close other/lib#5'
    refute_includes note, '#631'
  end

  # A fixes task relation renders `Fixes #N` under the summary, so the note checks it like summary text.
  def test_a_fixes_task_relation_is_checked_like_summary_text
    data = content('A neutral summary.').merge('provenance' => { 'task_source' => 'issue', 'task_number' => 818,
                                                                 'task_relation' => 'fixes' })
    note = Shaka::ClosingIssues.note(data, FakeGitHub.new([]))['closing_issues']

    assert_includes note, 'fixes #818, but GitHub will not close it'
    assert_equal({}, Shaka::ClosingIssues.note(data, FakeGitHub.new(['owner/repo#818'])))
    part = data.merge('provenance' => data['provenance'].merge('task_relation' => 'part_of'))
    assert_equal({}, Shaka::ClosingIssues.note(part, FakeGitHub.new([])))
  end

  def test_only_the_reference_after_the_keyword_is_claimed
    claimed = Shaka::ClosingIssues.claimed(['Fixes #680 for #710 of #683.'], 'owner/repo')

    assert_equal ['owner/repo#680'], claimed
  end

  def test_intent_fields_count_and_other_forms_normalize
    intent = { 'why' => 'Closes other/lib#3.', 'scope' => 'Resolves https://github.com/Owner/Repo/issues/9.',
               'leaves_out' => 'Fixes #99 later.' }
    claimed = Shaka::ClosingIssues.claimed(Shaka::ClosingIssues.texts('summary' => 'x', 'intent' => intent),
                                           'owner/repo')

    assert_equal ['other/lib#3', 'owner/repo#9'], claimed
  end

  def test_several_missing_issues_are_named_together
    note = note_for('Fixes #1, #2 & #3.', [])

    assert_includes note, 'fixes #1, #2, #3, but GitHub will not close them'
  end

  def test_an_unreadable_reference_list_is_reported_without_raising
    assert_includes note_for('Fixes #1.', :unreadable), 'could not be read'
    # Unexpected closes need the read even when the text claims nothing, so its failure shows there too.
    assert_includes note_for('Adds the check.', :unreadable), 'could not be read'
  end

  def test_a_partial_reference_page_is_reported_instead_of_trusted
    github = FakeGitHub.new(['owner/repo#1'], total: 101)

    assert_includes Shaka::ClosingIssues.note(content('Fixes #2.'), github)['closing_issues'], 'more closing issues'
    assert_includes Shaka::ClosingIssues.fact(github), 'closing issues unavailable'
  end

  def test_the_handoff_fact_names_the_issues_a_merge_closes
    linked = FakeGitHub.new(['owner/repo#839', 'other/lib#3'])

    assert_equal 'closes #839, other/lib#3', Shaka::ClosingIssues.fact(linked)
    assert_equal 'closes no issues', Shaka::ClosingIssues.fact(FakeGitHub.new([]))
    assert_includes Shaka::ClosingIssues.fact(FakeGitHub.new(:unreadable)), 'closing issues unavailable'
  end

  private

  def content(summary, task: nil)
    provenance = { 'task_source' => 'issue', 'task_number' => task } if task
    { 'summary' => summary, 'intent' => { 'why' => 'A problem.' }, 'provenance' => provenance }.compact
  end

  def note_for(summary, linked) = Shaka::ClosingIssues.note(content(summary), FakeGitHub.new(linked))['closing_issues']
end

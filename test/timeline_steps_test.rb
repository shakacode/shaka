# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'tmpdir'
require 'shaka/publication/timeline_steps'
require_relative 'support/timeline_steps_fixture'

# A pull request's measured steps come from this machine's call log and from the body's earlier updates.
class TimelineStepsTest < Minitest::Test
  include TimelineStepsFixture

  def test_a_validation_matches_by_tree_and_a_review_or_checkpoint_by_head
    checkpoint = record(command: 'post-implementation run', head: HEAD, provider: 'openai', model: 'gpt-6.1-sol',
                        effort: 'medium')
    steps = logged(validation, review, checkpoint)

    assert_equal(['evidence run', 'review run', 'post-implementation run'], steps.map { |step| step['command'] })
    assert_equal %w[gpt-6.1-sol medium m5], steps.last.values_at('model', 'effort', 'machine')
  end

  def test_other_repositories_commits_checks_and_commands_are_left_out
    other = 'c' * 40
    steps = logged(validation(repository: 'acme/other'), validation(tree: other), validation(check: 'setup'),
                   review(head: other), record(command: 'claim', number: 712), review(repository: 'acme/other'))
    assert_empty steps
  end

  def test_unreadable_lines_and_a_missing_log_are_skipped
    assert_equal 1, logged('not json', '[1]', "\xFF".b, review(duration_ms: nil), review(at: 'soon'), review).size
    assert_empty Shaka::TimelineSteps.logged('/nonexistent/calls.jsonl', REPOSITORY, COMMITS, 'm5')
    assert_empty logged(review, commits: [])
  end

  def test_carried_steps_come_back_and_a_step_logged_again_appears_once
    fresh = logged(validation, review)
    merged = Shaka::TimelineSteps.merge(Shaka::TimelineSteps.carried(body(fresh)), fresh)

    assert_equal fresh, merged
  end

  # Older steps beyond the cap are counted, so the section and later reports know the history is partial.
  def test_attach_keeps_the_newest_steps_sorted_and_counts_the_rest
    carried = pull(body(logged(validation), dropped: 3))
    timeline = with_log(*reviews_at_each_minute) { |log| attach(log, carried) }
    starts = timeline['steps'].map { |step| step['at'] }

    assert_equal [Shaka::TimelineSteps::MAX_STEPS, 14, starts.sort], [starts.size, timeline['dropped_steps'], starts]
  end

  # The log still holds the dropped steps, so an update with no new runs must not count them again,
  # including a dropped step that started in the same second as the oldest kept one.
  def test_an_unchanged_log_does_not_grow_the_dropped_count
    tie = review(at: '2026-10-21T10:10:00Z', provider: 'anthropic')
    counts = with_log(*reviews_at_each_minute, tie) do |log|
      first = attach(log, pull(''))
      second = attach(log, pull(body(first['steps'], dropped: first['dropped_steps'])))
      [first, second].map { |timeline| timeline['dropped_steps'] }
    end
    assert_equal [11, 11], counts
  end

  # The body is editable, so a carried step is checked again and an unsafe value never renders.
  def test_carried_steps_with_bad_fields_are_dropped_or_cleaned
    good = logged(review).first
    bad = [good.merge('id' => 'x'), good.merge('command' => 'claim'), good.merge('duration_ms' => -1),
           good.merge('at' => 'yesterday'), good.merge('check' => 'validate'), 'text']
    cleaned = good.merge('id' => 'f' * 16, 'model' => 'a | b', 'machine' => '<script>')
    carried = Shaka::TimelineSteps.carried(body([*bad, cleaned]))

    assert_equal [good.merge('id' => 'f' * 16).except('machine')], carried
  end

  def test_only_the_managed_region_is_read
    line = Shaka::TimelineSteps.hidden(logged(review))
    assert_empty Shaka::TimelineSteps.carried("#{line}\n<!-- shaka:begin -->\n<!-- shaka:end -->\n")
    assert_empty Shaka::TimelineSteps.carried(region('<!-- timeline-steps {oops} -->'))
    assert_equal [[], 0], Shaka::TimelineSteps.read(region('<!-- timeline-steps {"dropped":-2} -->'))
  end

  def test_attach_adds_carried_and_logged_steps_to_the_timeline
    Dir.mktmpdir do |directory|
      log = File.join(directory, 'calls.jsonl')
      File.write(log, "#{JSON.generate(review)}\n")
      steps = attached(log, pull(body(logged(validation))))

      assert_equal(['evidence run', 'review run'], steps.map { |step| step['command'] })
      refute steps.last.key?('machine')
    end
  end

  # A fork's author can edit its body, so only this machine's own log counts there.
  def test_a_fork_carries_no_steps_from_its_body
    Dir.mktmpdir do |directory|
      log = File.join(directory, 'calls.jsonl')
      File.write(log, "#{JSON.generate(review)}\n")
      fork = pull(body(logged(validation)), head: 'someone/widgets')

      assert_equal ['review run'], commands(attached(log, fork))
      assert_equal ['review run'], commands(attached(log, fork.merge('head' => nil)))
    end
  end
end

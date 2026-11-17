# frozen_string_literal: true

require_relative 'update_check_support'

# A registered checkout asks GitHub at most once a day for the commit and record it has installed.
class UpdateCheckSavedAnswerTest < Minitest::Test
  include UpdateCheckSupport

  HOUR = 60 * 60
  TARGET = 'shakacode/shaka main'
  CURRENT = { 'status' => 'current', 'guidance' => 'This installed revision matches shakacode/shaka main.' }.freeze

  def setup
    @directory = Dir.mktmpdir('update-check-saved')
    @home = File.join(@directory, 'home')
    @checkout = File.join(@directory, 'checkout')
    FileUtils.mkdir_p(@checkout)
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_a_saved_answer_stands_in_for_github_for_most_of_a_day
    at = (Time.now - (22 * HOUR)).utc.iso8601
    save('available', at: Time.iso8601(at))
    instance = checker('identical', checkout: @checkout, home: @home)
    result = instance.result
    assert_equal ['available guidance', at], result.values_at('guidance', 'checked_at')
    refute_predicate self, :github_asked?
    instance.remember(result)
    assert_equal at, saved.fetch('checked_at'), 'a repeated answer keeps its own age'
  end

  # A check scheduled at the same time each day starts a few seconds short of a day after the last one.
  def test_an_answer_from_this_time_yesterday_asks_github_again
    save('available', at: Time.now - (24 * HOUR) + 2)
    assert_equal 'current', check('identical', checkout: @checkout, home: @home).fetch('status')
    assert_predicate self, :github_asked?
  end

  # install --update moves HEAD, records a manual pull, or both, and a reinstall can track another branch.
  # An answer worked out without GitHub names no comparison, and a copy without a record saves nothing.
  def test_another_installation_comparison_or_unregistered_copy_asks_github_again
    [{ commit: PULLED }, { revision: PULLED }, { compared: 'shakacode/shaka next' }, { compared: nil }]
      .each do |installed|
        save('available', **installed)
        assert_equal 'current', check('identical', checkout: @checkout, home: @home).fetch('status'), installed.inspect
      end
    save('available')
    assert_equal 'current', check('identical', checkout: nil, home: @home).fetch('status')
  end

  def test_an_answer_saved_before_answers_named_their_commit_asks_github_again
    Shaka::UpdateCheck::Cache.write(@home, { 'checkout' => File.realpath(@checkout), 'result' => CURRENT,
                                             'checked_at' => Time.now.utc.iso8601 })
    check('identical', checkout: @checkout, home: @home)
    assert_predicate self, :github_asked?
  end

  def test_a_new_answer_is_saved_with_the_commit_and_record_it_describes
    instance = checker('identical', checkout: @checkout, home: @home)
    instance.remember(instance.result)
    assert_equal [SHA, SHA, TARGET, CURRENT], saved.values_at('commit', 'revision', 'compared', 'result')
  end

  # Answers that need no request are worked out again, so a moved or unreadable checkout is reported at once.
  def test_answers_without_a_request_ignore_the_saved_one
    save('available')
    moved = check('identical', checkout: @checkout, home: @home, head: PULLED, pulled: ['', '', false])
    assert_equal %w[drift not_a_pull], moved.values_at('status', 'reason')
    unreadable = check('identical', checkout: @checkout, home: @home, head: 'not a commit')
    assert_equal %w[unknown checkout_unreadable], unreadable.values_at('status', 'reason')
  end

  private

  def save(status, at: Time.now - HOUR, commit: SHA, revision: SHA, compared: TARGET)
    Shaka::UpdateCheck::Cache.record(@checkout, { 'status' => status, 'guidance' => "#{status} guidance" },
                                     installed: { 'commit' => commit, 'revision' => revision, 'compared' => compared },
                                     home: @home, now: at)
  end

  def saved = JSON.parse(File.read(Shaka::UpdateCheck::Cache.path(@home)))

  def github_asked? = @calls.any? { |argv, _directory| argv.first == 'gh' }
end

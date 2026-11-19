# frozen_string_literal: true

require_relative 'startup_notice_support'

# Which saved update-check answer the startup notices treat as this installation's.
class StartupNoticeSavedAnswerTest < Minitest::Test
  include StartupNoticeSupport

  DAY = Shaka::UpdateCheck::Cache::SECONDS

  def test_another_checkouts_answer_counts_as_missing
    other = checkout('other', registered: true)
    save(other, answer('available'))
    assert_match(/not checked/, notice)
  end

  def test_a_checkout_reached_through_a_link_shares_its_entry
    linked = File.join(@directory, 'linked checkout')
    File.symlink(@root, linked)
    save(linked, answer('available'))
    assert_equal 'shaka: available guidance', notice(now: NOW + 60)
  end

  # install and install --update change the record, so an answer saved before them describes the earlier
  # installation. Neither notice repeats it, and only a day without a check brings the reminder.
  def test_an_answer_for_an_earlier_installation_stays_quiet
    [{ 'revision' => 'c' * 40 }, {}].each do |installed|
      Shaka::UpdateCheck::Cache.write(@home, { 'checkout' => @root, 'checked_at' => NOW.utc.iso8601,
                                               'result' => answer('available'), **installed })
      assert_nil notice(now: NOW + 60)
      assert_empty session_start(now: NOW + 60)
      assert_match(/not checked/, notice(now: NOW + DAY + 1))
    end
  end
end

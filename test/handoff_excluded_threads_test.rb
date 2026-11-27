# frozen_string_literal: true

require_relative 'handoff_helper'

# #1323: `reply` refuses a public thread that includes an author `comments` excludes, so handoff
# leaves such a thread to a person instead of owing it.
class HandoffExcludedThreadsTest < Minitest::Test
  include HandoffHarness

  EXCLUDED_T1 = 'Review thread T1 includes an author `comments` excludes, so the agent cannot reply there. ' \
                'A maintainer can answer on GitHub and resolve it, or add the author to the trusted actors.'

  def test_a_public_thread_opened_by_an_excluded_author_is_a_note_not_owed
    result = handoff(visibility: 'public', threads: [thread('T1', opener: 'outsider')])

    assert_empty result['owed']
    assert_equal 0, Shaka::Handoff.exit_status(result)
    assert_includes result['notes'], EXCLUDED_T1
  end

  def test_an_excluded_reply_in_a_trusted_authors_thread_makes_it_a_note
    threads = [thread('T1', opener: 'reviewer', replies: ['outsider'])]
    result = handoff(visibility: 'public', trusted: ['reviewer'], threads:)

    assert_empty result['owed']
    assert_includes result['notes'], EXCLUDED_T1
  end

  def test_threads_from_allowed_authors_stay_owed_beside_an_excluded_one
    threads = [thread('T1', opener: 'outsider'), thread('T2', opener: 'maintainer'),
               thread('T3', opener: 'reviewer'), thread('T4', opener: 'coderabbitai[bot]')]
    result = handoff(visibility: 'public', writers: ['maintainer'], trusted: ['reviewer'], threads:)

    assert_equal ['Reply on review threads waiting for an answer: T2, T3.'], result['owed']
    assert_includes result['notes'], 'Review threads T1, T4 include an author `comments` excludes, so the agent ' \
                                     'cannot reply there. A maintainer can answer on GitHub and resolve it, or ' \
                                     'add the author to the trusted actors.'
  end

  def test_a_private_repository_owes_every_unanswered_thread
    result = handoff(visibility: 'private', threads: [thread('T1', opener: 'outsider')])

    assert_equal ['Reply on review threads waiting for an answer: T1.'], result['owed']
    assert_empty result['notes']
  end

  def test_the_persons_own_unmarked_comment_is_not_screened
    result = handoff(visibility: 'public', threads: [thread('T1', opener: ['shaka-agent', 'Rename this.'])])

    assert_equal ['Reply on review threads waiting for an answer: T1.'], result['owed']
  end

  def test_an_unreadable_visibility_keeps_the_thread_owed_with_a_note
    result = handoff(visibility: :unreadable, threads: [thread('T1', opener: 'outsider')])

    assert_equal ['Reply on review threads waiting for an answer: T1.'], result['owed']
    assert_includes result['notes'], 'Thread authors are unscreened: Repository visibility is unavailable.'
  end

  # A failed permission read is not evidence that the author is excluded, but `reply` still refuses.
  def test_an_unverifiable_author_keeps_the_thread_owed_with_a_note
    result = handoff(visibility: 'public', unverifiable: ['outsider'], threads: [thread('T1', opener: 'outsider')])

    assert_equal ['Reply on review threads waiting for an answer: T1.'], result['owed']
    assert_includes result['notes'], 'Review thread T1 includes an author whose permission GitHub did not ' \
                                     'return; `reply` refuses there until it does.'
  end

  def test_a_confirmed_exclusion_outweighs_an_unverifiable_author_in_the_same_thread
    threads = [thread('T1', opener: 'stranger', replies: ['outsider'])]
    result = handoff(visibility: 'public', unverifiable: ['stranger'], threads:)

    assert_empty result['owed']
    assert_includes result['notes'], EXCLUDED_T1
  end

  # #1323 review: one thread's failed read must not decide another's.
  def test_each_thread_is_screened_on_its_own
    threads = [thread('T1', opener: 'outsider'), thread('T2', opener: 'stranger')]
    result = handoff(visibility: 'public', unverifiable: ['stranger'], threads:)

    assert_equal ['Reply on review threads waiting for an answer: T2.'], result['owed']
    assert_includes result['notes'], EXCLUDED_T1
  end

  def test_unreadable_trusted_actor_settings_keep_the_thread_owed
    result = handoff(visibility: 'public', trust_from_github: true, threads: [thread('T1', opener: 'outsider')])

    assert_equal ['Reply on review threads waiting for an answer: T1.'], result['owed']
    assert_includes result['notes'],
                    'Thread authors are unscreened on T1: Trusted default-branch commit is unavailable.'
  end

  # An earlier agent reply lets `resolve` run, so the note claims only that the reply is refused.
  def test_an_excluded_comment_after_the_agents_answer_is_a_note
    threads = [thread('T1', opener: 'reviewer', replies: %w[shaka-agent outsider])]
    result = handoff(visibility: 'public', trusted: ['reviewer'], threads:)

    assert_empty result['owed']
    assert_includes result['notes'], EXCLUDED_T1
  end

  def test_configured_bots_and_team_members_stay_owed
    threads = [thread('T1', opener: 'coderabbitai[bot]'), thread('T2', opener: 'teammate')]
    result = handoff(visibility: 'public', bots: ['coderabbitai'], teams: [%w[owner core]], team_members: ['teammate'],
                     threads:)

    assert_equal ['Reply on review threads waiting for an answer: T1, T2.'], result['owed']
    assert_empty result['notes']
  end

  def test_the_default_branch_allowlist_decides_who_stays_owed
    allowlist = "trusted_users:\n  - reviewer\ntrusted_bots: []\ntrusted_metadata_bots: []\ntrusted_teams: []\n"
    threads = [thread('T1', opener: 'outsider'), thread('T2', opener: 'reviewer')]
    result = handoff(visibility: 'public', trust_from_github: true, allowlist:, threads:)

    assert_equal ['Reply on review threads waiting for an answer: T2.'], result['owed']
    assert_includes result['notes'], EXCLUDED_T1
  end

  def test_threads_with_the_same_authors_read_each_permission_once
    reads = []
    threads = %w[T1 T2 T3].map { |id| thread(id, opener: 'maintainer') }
    result = handoff(visibility: 'public', writers: ['maintainer'], permission_reads: reads, threads:)

    assert_equal ['Reply on review threads waiting for an answer: T1, T2, T3.'], result['owed']
    assert_equal ['maintainer'], reads
  end

  def test_an_answered_thread_is_not_screened
    result = handoff(visibility: :unreadable, threads: [thread('T1', opener: 'outsider', replies: ['shaka-agent'])])

    assert_empty result['owed']
    assert_empty result['notes']
  end
end

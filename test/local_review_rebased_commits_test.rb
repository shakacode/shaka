# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require_relative '../skills/shaka/lib/shaka/local_review/rebased_commits'
require_relative '../skills/shaka/lib/shaka/local_review/summary'

# A reviewed commit rebased before it was pushed links to its pushed copy.
class LocalReviewRebasedCommitsTest < Minitest::Test
  PULL = Struct.new(:commits) do
    def number = 7

    def api(path)
      raise "unexpected #{path}" unless path == 'repos/o/r/pulls/7/commits?per_page=100'

      commits
    end
  end

  def setup
    @root = Dir.mktmpdir
    git('init', '--quiet')
    git('-c', 'user.name=Reviewer', '-c', 'user.email=r@example.test', 'commit', '--quiet', '--allow-empty',
        '-m', "Add review publication\n\nBody", env: { 'GIT_AUTHOR_DATE' => '2026-10-13T22:10:00-07:00' })
    @reviewed = git('rev-parse', 'HEAD').strip
  end

  def teardown = FileUtils.remove_entry(@root)

  def test_the_pull_request_commit_with_the_same_subject_and_author_date_is_the_copy
    copy = pushed('b' * 40, '2026-10-14T05:10:00Z')
    other = pushed('c' * 40, '2026-10-14T06:00:00Z')

    assert_equal 'b' * 40, rebased([other, copy]).call(@reviewed)
  end

  def test_no_copy_without_a_unique_match_or_the_local_commit
    twins = [pushed('b' * 40, '2026-10-14T05:10:00Z'), pushed('c' * 40, '2026-10-14T05:10:00Z')]

    assert_nil rebased(twins).call(@reviewed)
    assert_nil rebased([pushed('b' * 40, '2026-10-14T05:10:00Z')]).call('d' * 40)
  end

  def test_a_link_names_the_reviewed_commit_and_opens_its_copy
    links = Shaka::LocalReviewLinks.new('o/r', ->(_) { false }, ->(_) { 'b' * 40 })

    assert_equal "`#{@reviewed[0, 7]}`, rebased as [`bbbbbbb`](https://github.com/o/r/commit/#{'b' * 40})",
                 links.commit(@reviewed)
    assert_equal "`#{@reviewed[0, 7]}` (not on GitHub)",
                 Shaka::LocalReviewLinks.new('o/r', ->(_) { false }, ->(_) {}).commit(@reviewed)
  end

  private

  def rebased(commits) = Shaka::LocalReviewRebasedCommits.new(PULL.new(commits), 'o/r', root: @root)

  def pushed(sha, date)
    { 'sha' => sha, 'commit' => { 'message' => "Add review publication\n\nBody", 'author' => { 'date' => date } } }
  end

  def git(*, env: {})
    output, error, status = Open3.capture3(env, 'git', '-C', @root, *)
    raise error unless status.success?

    output
  end
end

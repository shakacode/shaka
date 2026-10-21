# frozen_string_literal: true

require_relative 'post_implementation_publication_test'
require_relative 'repository_fixture'

# Answers the size and changed-file reads the preview makes beside the checkpoint's own.
class PreviewGitHub < PostImplementationPublicationFixture::GitHub
  attr_accessor :files, :changed_files

  def snapshot
    super.merge('changedFiles' => files.length, 'additions' => 40, 'deletions' => 10)
  end

  def api(path, **)
    pull = super
    path.end_with?('/pulls/1') ? pull.merge('changed_files' => changed_files || files.length) : pull
  end

  def api_list(path)
    return files.map { |name| { 'filename' => name } } if path.include?('/pulls/1/files')

    super
  end
end

# A ready checkpoint on Ask says whether merge.auto_max_review_floor would have let Auto merge the PR.
class CheckpointAutoMergePreviewTest < Minitest::Test
  include PostImplementationPublicationFixture
  include RepositoryConfigTestHelpers

  def body_for(files, merge: { 'preference' => 'ask', 'auto_max_review_floor' => 2 }, changed_files: nil)
    with_repository('merge' => merge) do |root|
      trust!(root)
      with_result do |result, path|
        github = PreviewGitHub.new('a' * 40)
        github.files = files
        github.changed_files = changed_files
        publish_at(root, result, path, github)
        return github.bodies.first.first
      end
    end
  end

  def test_says_auto_would_merge_code_at_the_floor
    assert_includes body_for(%w[lib/fix.rb test/fix_test.rb]),
                    '**Auto merge preview:** with `merge.preference: auto`, the agent would merge this PR.'
  end

  def test_names_the_file_that_would_hand_the_pr_back
    assert_includes body_for(%w[lib/fix.rb skills/shaka/SKILL.md]),
                    'would hand this PR back: skills/shaka/SKILL.md sets review floor 3 (changes agent instructions)'
  end

  def test_counts_merge_limits
    files = (1..30).map { |n| "lib/f#{n}.rb" }

    assert_includes body_for(files), 'would hand this PR back: it is past `merge.limits` (changed_files 30 > 29).'
  end

  def test_names_both_limits_and_the_held_file
    files = [*(1..29).map { |n| "lib/f#{n}.rb" }, 'skills/shaka/SKILL.md']

    assert_includes body_for(files), '(changed_files 30 > 29); skills/shaka/SKILL.md sets review floor 3'
  end

  def test_an_unreadable_file_list_is_named_plainly
    assert_includes body_for(%w[lib/fix.rb], changed_files: 2),
                    'would hand this PR back: Shaka could not read its changed files from GitHub.'
  end

  def test_no_preview_under_auto_or_at_the_top_floor
    [{ 'preference' => 'auto', 'auto_max_review_floor' => 2 }, { 'preference' => 'ask' }].each do |merge|
      refute_includes body_for(%w[lib/fix.rb], merge:), 'Auto merge preview'
    end
  end

  private

  def trust!(root)
    system('git', '-C', root, 'init', '--quiet', exception: true)
    system('git', '-C', root, 'add', '.', exception: true)
    system('git', '-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
           'commit', '--quiet', '-m', 'trusted', exception: true)
  end

  def publish_at(root, result, path, github)
    File.write(path, JSON.generate(result))
    arguments = ['publish', 'example/test', '1', '--content-file', path, '--squash-message', message_file(path),
                 '--root', root, '--ref', 'HEAD']
    capture_io { assert_equal 0, Shaka::PostImplementation.run(arguments, github:) }
  end
end

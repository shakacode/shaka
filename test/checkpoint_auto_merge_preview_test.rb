# frozen_string_literal: true

require_relative 'post_implementation_publication_test'
require_relative 'repository_fixture'

# Answers the size and changed-file reads the preview makes beside the checkpoint's own.
class PreviewGitHub < PostImplementationPublicationFixture::GitHub
  attr_accessor :files, :changed_files, :labels

  def snapshot
    names = labels || []
    super.merge('changedFiles' => files.length, 'additions' => 40, 'deletions' => 10,
                'labels' => { 'totalCount' => names.length, 'nodes' => names.map { |name| { 'name' => name } } })
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

  # client sets PreviewGitHub's changed_files or labels.
  def body_for(files, merge: { 'preference' => 'ask', 'auto_max_review_floor' => 2 }, verdict: nil, **client)
    with_repository('merge' => merge) do |root|
      trust!(root)
      with_result do |result, path|
        change_verdict(result, verdict) if verdict
        github = PreviewGitHub.new('a' * 40).tap { |client| client.files = files }
        client.each { |key, value| github.public_send("#{key}=", value) }
        publish_at(root, result, path, github)
        return github.bodies.first.first
      end
    end
  end

  def change_verdict(result, verdict)
    report = JSON.parse(File.read(result['report']))
    adequacy = ADEQUACY.merge('verdict' => verdict)
    File.write(result['report'], JSON.generate(report.merge('verification_adequacy' => adequacy)))
  end

  def test_a_verdict_that_stops_auto_hands_the_pr_back
    assert_includes body_for(%w[lib/fix.rb], verdict: 'cannot judge'),
                    "would hand this PR back: the checkpoint's verdict on its verification is cannot judge."
    refute_includes body_for(%w[lib/fix.rb], verdict: 'adequate with accepted gaps'), 'hand this PR back'
  end

  def test_says_code_at_the_floor_passes_without_promising_a_merge
    assert_includes body_for(%w[lib/fix.rb test/fix_test.rb]),
                    '**Auto merge preview:** this PR passes the review floor and size checks Auto applies; ' \
                    'the agent would still judge its risk and compatibility before merging.'
  end

  def test_names_the_file_that_would_hand_the_pr_back
    assert_includes body_for(%w[lib/fix.rb skills/shaka/SKILL.md]),
                    'would hand this PR back: skills/shaka/SKILL.md sets review floor 3 (changes agent instructions)'
  end

  def test_names_a_hold_label_whatever_the_files
    assert_includes body_for(%w[lib/fix.rb], labels: %w[bug Hold]),
                    'would hand this PR back: it carries the hold label `Hold`.'
    assert_includes body_for(%w[lib/fix.rb], labels: ['do-not-merge'],
                                             merge: { 'preference' => 'ask', 'auto_max_review_floor' => 2,
                                                      'hold_labels' => ['do-not-merge'] }),
                    'it carries the hold label `do-not-merge`'
    assert_includes body_for(%w[skills/shaka/SKILL.md], labels: ['hold'], merge: { 'preference' => 'ask' }),
                    'would hand this PR back: it carries the hold label `hold`.'
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

  def test_unreadable_settings_leave_the_preview_out_and_still_publish
    with_result do |result, path|
      github = PreviewGitHub.new('a' * 40)
      github.files = %w[lib/fix.rb]
      Dir.mktmpdir { |empty| publish_at(empty, result, path, github) }

      refute_includes github.bodies.first.first, 'Auto merge preview'
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

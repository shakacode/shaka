# frozen_string_literal: true

require_relative 'local_review_test'

class LocalReviewCommitExportTest < Minitest::Test
  include LocalReviewFixture

  COMMAND = LocalReviewCodexTest::COMMAND

  # Break caught: Claude is left with only the diff, or reads untracked files and links out of the export.
  def test_claude_reads_only_the_reviewed_commit_files
    with_repository do |root, base, _head, bin|
      head = commit_caller_and_link!(root)
      trace = fake_export_reader(root, bin, head)
      output, error, status = run_review(root, base, head, bin, env: { 'REVIEW_TRACE' => trace },
                                                                reviewer: 'anthropic/claude')
      result = assert_successful_review(output, error, status, head, 'anthropic/claude')
      assert_export_seen(JSON.parse(File.read(trace)), result)
    ensure
      cleanup_artifacts(result)
    end
  end

  # Break caught: a Codex review starts depending on an export it does not need.
  def test_codex_gets_no_export
    with_repository do |root, base, head, bin|
      trace = File.join(root, 'codex-invocation.json')
      fake_codex(bin, head)

      output, error, status = run_review(root, base, head, bin, env: { 'REVIEW_TRACE' => trace })

      result = assert_successful_review(output, error, status, head, 'openai/codex')
      refute_includes JSON.parse(File.read(trace)).fetch('args'), '--add-dir'
    ensure
      cleanup_artifacts(result)
    end
  end

  # Break caught: one of two colliding paths silently replaces the other in what Claude reads.
  def test_paths_that_collide_on_this_filesystem_stop_the_review
    with_repository do |root, base, _head, bin|
      skip 'this filesystem distinguishes case' unless case_insensitive?(bin)
      head = commit_colliding_paths!(root)
      fake_claude(bin, head)
      output, _error, status = run_review(root, base, head, bin, reviewer: 'anthropic/claude')
      refute_predicate status, :success?
      assert_includes JSON.parse(output).fetch('reason'), 'already exists, no checkout'
    end
  end

  private

  def case_insensitive?(directory)
    File.write(File.join(directory, 'Probe'), '')
    File.exist?(File.join(directory, 'probe'))
  end

  # The index takes both names even where the checkout cannot hold them.
  def commit_colliding_paths!(root)
    blob = git!(root, 'hash-object', '-w', 'example.txt').strip
    %w[Same.txt same.txt].each do |path|
      git!(root, 'update-index', '--add', '--cacheinfo', "100644,#{blob},#{path}")
    end
    git!(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-m', 'collide')
    # One file on disk now stands for both names, so the checkout reads as clean.
    FileUtils.cp(File.join(root, 'example.txt'), File.join(root, 'same.txt'))
    git!(root, 'rev-parse', 'HEAD').strip
  end

  def commit_caller_and_link!(root)
    File.write(File.join(root, 'caller.rb'), "call_example\n")
    File.write(File.join(root, '.gitattributes'), "caller.rb export-ignore\n")
    File.symlink('/etc/hosts', File.join(root, 'outside-link'))
    # Ignored and untracked, so the checkout stays clean while the file stays out of the commit.
    File.write(File.join(root, 'pr-description.txt'), "ignored secret\n")
    git!(root, 'add', '.')
    git!(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-m', 'caller')
    git!(root, 'rev-parse', 'HEAD').strip
  end

  def assert_export_seen(invocation, result)
    args = invocation.fetch('args')
    assert_includes args, '--safe-mode'
    export = args.fetch(args.index('--add-dir') + 1)
    assert_equal %w[.gitattributes AGENTS.md caller.rb example.txt], invocation.fetch('files')
    assert_includes invocation.fetch('prompt'), export.to_json
    refute_path_exists export
    assert_includes result.fetch('coverage'), 'export of the reviewed commit'
  end

  # Records what the export holds while the reviewer runs; the runner removes it afterward.
  def fake_export_reader(root, bin, head)
    write_executable(bin, 'claude', <<~RUBY)
      #!/usr/bin/env ruby
      require 'json'
      export = ARGV.fetch(ARGV.index('--add-dir') + 1)
      files = Dir.children(export).sort
      File.write(ENV.fetch('REVIEW_TRACE'), JSON.generate({ args: ARGV, prompt: STDIN.read, files: files }))
      puts JSON.generate({ is_error: false, result: "no findings\\nREVIEWED #{head} BY anthropic/claude EFFORT medium FINDINGS 0" })
    RUBY
    File.join(root, 'claude-invocation.json')
  end
end

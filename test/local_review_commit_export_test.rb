# frozen_string_literal: true

require_relative 'local_review_test'
require_relative '../skills/shaka/lib/shaka/local_review/commit_export'
require_relative '../skills/shaka/lib/shaka/post_implementation_runner'

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
      assert_export_seen(JSON.parse(File.read(trace)), result, root)
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
    assert_collision_stops_review(%w[Same.txt same.txt])
  end

  # Break caught: two committed directories differing in case merged into one in the export.
  def test_directories_that_collide_on_this_filesystem_stop_the_review
    assert_collision_stops_review(%w[Dir/first.txt dir/second.txt])
  end

  private

  def assert_collision_stops_review(paths)
    with_repository do |root, base, _head, bin|
      skip 'this filesystem distinguishes case' unless case_insensitive?(bin)
      head = commit_colliding_paths!(root, paths)
      fake_claude(bin, head)
      output, _error, status = run_review(root, base, head, bin, reviewer: 'anthropic/claude')
      refute_predicate status, :success?
      assert_includes JSON.parse(output).fetch('reason'), 'collides with another committed path'
    end
  end

  def case_insensitive?(directory)
    File.write(File.join(directory, 'Probe'), '')
    File.exist?(File.join(directory, 'probe'))
  end

  # The index takes both names even where the filesystem cannot hold them.
  def commit_colliding_paths!(root, paths)
    blob = git!(root, 'hash-object', '-w', 'example.txt').strip
    paths.each { |path| git!(root, 'update-index', '--add', '--cacheinfo', "100644,#{blob},#{path}") }
    git!(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-m', 'collide')
    # The filesystem folds the names together, so writing each one leaves the checkout clean.
    paths.each do |path|
      FileUtils.mkdir_p(File.dirname(File.join(root, path)))
      FileUtils.cp(File.join(root, 'example.txt'), File.join(root, path))
    end
    git!(root, 'rev-parse', 'HEAD').strip
  end

  # The smudge filter would rewrite caller.rb and leave a marker if the export ran checkout filters.
  def commit_caller_and_link!(root)
    File.write(File.join(root, 'caller.rb'), "call_example\n")
    File.write(File.join(root, '.gitattributes'), "caller.rb export-ignore filter=upcase\n")
    git!(root, 'config', 'filter.upcase.smudge', "touch #{smudge_marker(root)}; tr a-z A-Z")
    write_nested_link(root)
    # Ignored and untracked, so the checkout stays clean while the file stays out of the commit.
    File.write(File.join(root, 'pr-description.txt'), "ignored secret\n")
    git!(root, 'add', '.')
    git!(root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com', 'commit', '-m', 'caller')
    git!(root, 'rev-parse', 'HEAD').strip
  end

  def write_nested_link(root)
    FileUtils.mkdir_p(File.join(root, 'dir'))
    File.write(File.join(root, 'dir', 'inner.txt'), "inner\n")
    File.symlink('/etc/hosts', File.join(root, 'dir', 'outside-link'))
  end

  def smudge_marker(root) = "#{root}.smudged"

  def assert_export_seen(invocation, result, root)
    args = invocation.fetch('args')
    assert_includes args, '--safe-mode'
    export = args.fetch(args.index('--add-dir') + 1)
    assert_includes invocation.fetch('prompt'), export.to_json
    refute_path_exists export
    assert_includes result.fetch('coverage'), 'export of the reviewed commit'
    assert_exported_bytes(invocation, root)
  end

  # Raw committed bytes: no export-ignore, no smudge filter run, no link, no untracked file.
  def assert_exported_bytes(invocation, root)
    assert_equal %w[.gitattributes AGENTS.md caller.rb dir dir/inner.txt example.txt], invocation.fetch('files')
    assert_equal "call_example\n", invocation.fetch('caller')
    refute_path_exists smudge_marker(root)
  end

  # Records what the export holds while the reviewer runs; the runner removes it afterward.
  def fake_export_reader(root, bin, head)
    write_executable(bin, 'claude', <<~RUBY)
      #!/usr/bin/env ruby
      require 'json'
      export = ARGV.fetch(ARGV.index('--add-dir') + 1)
      files = Dir.glob('**/*', File::FNM_DOTMATCH, base: export).reject { |path| File.basename(path) == '.' }.sort
      caller = File.read(File.join(export, 'caller.rb'))
      File.write(ENV.fetch('REVIEW_TRACE'), JSON.generate({ args: ARGV, prompt: STDIN.read, files:, caller: }))
      puts JSON.generate({ is_error: false, result: "no findings\\nREVIEWED #{head} BY anthropic/claude EFFORT medium FINDINGS 0" })
    RUBY
    File.join(root, 'claude-invocation.json')
  end
end

# Exercises export parsing and path checks directly, where a Git checkout cannot hold the input.
class LocalReviewCommitExportUnitTest < Minitest::Test
  # Stands in for the runner: replies to each Git call with fixed output.
  class Exporter
    include Shaka::LocalReviewCommitExport

    def initialize(listing, blobs)
      @listing = listing
      @blobs = blobs
      @options = {}
    end

    def run(directory) = export_commit(directory)

    private

    def capture(*_arguments, stdin: nil)
      stdin ? @blobs : @listing
    end

    def git_executable = 'git'
    def root = '/repo'
    def head = 'abc'
  end

  ID = 'a' * 40

  # Break caught: a name that is not UTF-8 raised ArgumentError, which the runner does not rescue.
  def test_path_names_are_read_as_bytes
    # LocalReviewProcess labels stdout UTF-8 whatever bytes Git wrote.
    listing = "100644 blob #{ID}\tbad\xFF.txt\0".force_encoding(Encoding::UTF_8)
    exporter = Exporter.new(listing, "#{ID} blob 1\nx\n")
    entries = exporter.send(:commit_entries)
    assert_equal [[ID, "bad\xFF.txt".b]], entries
  end

  # Break caught: File.expand_path read a leading ~ as a home directory.
  def test_tilde_names_stay_inside_the_export
    Dir.mktmpdir do |temporary|
      directory = File.realpath(temporary)
      Exporter.new("100644 blob #{ID}\t~$Report.docx\0", "#{ID} blob 1\nx\n").run(directory)
      assert_equal 'x', File.read(File.join(directory, '~$Report.docx'))
    end
  end

  def test_parent_components_are_refused
    Dir.mktmpdir do |temporary|
      directory = File.realpath(temporary)
      error = assert_raises(Shaka::Error) do
        Exporter.new("100644 blob #{ID}\tdir/../../escape\0", "#{ID} blob 1\nx\n").run(directory)
      end
      assert_includes error.message, 'leaves the export'
    end
  end

  # Break caught: a short read wrote a truncated file as if it were the committed content.
  def test_truncated_blob_output_stops_the_export
    Dir.mktmpdir do |temporary|
      directory = File.realpath(temporary)
      error = assert_raises(Shaka::Error) do
        Exporter.new("100644 blob #{ID}\tfile.txt\0", "#{ID} blob 5\nab").run(directory)
      end
      assert_includes error.message, 'incomplete blob'
    end
  end
end

class PostImplementationCommitExportTest < Minitest::Test
  # Break caught: an opted-out Claude checkpoint exported the commit and could fail before saying opted_out.
  def test_only_an_active_claude_checkpoint_exports
    exports = [{ opt_out: 'Maintainer decision' }, {}].map do |options|
      Shaka::PostImplementationRunner.new(options.merge(reviewer: 'anthropic/claude')).send(:commit_export?)
    end
    assert_equal [false, true], exports
  end
end

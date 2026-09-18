# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'tmpdir'
require 'shaka/snapshot'

# A push cannot be taken back, so the screen decides what may leave the machine.
class SnapshotScreenTest < Minitest::Test
  def test_ordinary_unfinished_work_is_published
    paths = ['README.md', 'docs/research.md', 'lib/thing.rb', 'notes/token-economics.md.bak']
    screen = Shaka::Snapshot::Screen.new(paths)

    assert_equal ['README.md', 'docs/research.md', 'lib/thing.rb'], screen.included
  end

  def test_credential_files_without_an_extension_are_held_back
    paths = ['.aws/credentials', 'config/credentials', '.pgpass', '.docker/config.json',
             '.ssh/known_hosts', 'vendor/secrets']
    screen = Shaka::Snapshot::Screen.new(paths)

    assert_empty screen.included
  end

  def test_credentials_are_held_back_whatever_the_directory
    paths = ['.env', 'app/.env.local', 'deploy/id_rsa', 'certs/server.pem', 'config/credentials.json',
             'scripts/rotate_api_key.sh', '.netrc']
    screen = Shaka::Snapshot::Screen.new(paths)

    assert_empty screen.included
    assert_equal paths.sort, screen.excluded.sort
  end
end

# Git reports a rename as two fields and a deletion as an ordinary change.
class SnapshotChangesTest < Minitest::Test
  def test_a_rename_adds_its_destination_and_removes_its_source
    changes = Shaka::Snapshot::Changes.new(['R  gamma.txt', 'alpha.txt'])

    assert_equal ['gamma.txt'], changes.added
    assert_equal ['alpha.txt'], changes.removed
  end

  def test_a_copy_keeps_its_source
    changes = Shaka::Snapshot::Changes.new(['C  copy.txt', 'origin.txt'])

    assert_equal ['copy.txt'], changes.added
    assert_empty changes.removed
  end

  def test_a_rename_detected_in_the_worktree_column_is_read_the_same_way
    changes = Shaka::Snapshot::Changes.new([' R gamma.txt', 'alpha.txt', ' M kept.txt'])

    assert_equal ['gamma.txt', 'kept.txt'], changes.added
    assert_equal ['alpha.txt'], changes.removed
  end

  def test_deleted_files_are_removed_rather_than_added
    changes = Shaka::Snapshot::Changes.new([' D beta.txt', '?? delta.txt', ' M kept.txt'])

    assert_equal ['delta.txt', 'kept.txt'], changes.added
    assert_equal ['beta.txt'], changes.removed
  end
end

# Builds a throwaway repository so the snapshot runs against real git.
module SnapshotRepository
  def run_snapshot(work, *arguments)
    output = nil
    Dir.chdir(work) do
      output = capture_io { assert_equal 0, Shaka::Snapshot.new(arguments).run }.first
    end
    JSON.parse(output)
  end

  def published_files(work, commit)
    git(work, 'ls-tree', '--name-only', '-r', commit).split("\n").sort
  end

  def remote_branches(work)
    git(work, 'ls-remote', '--heads', 'origin').split("\n")
  end

  def add_submodule(work)
    source = File.join(File.dirname(work), 'nested-source')
    git(File.dirname(work), 'init', '--quiet', source)
    git(source, 'config', 'user.email', 'test@example.com')
    git(source, 'config', 'user.name', 'Test')
    File.write(File.join(source, 'README.md'), "nested\n")
    git(source, 'add', '--all')
    git(source, 'commit', '--quiet', '--message', 'nested')
    git(work, '-c', 'protocol.file.allow=always', 'submodule', '--quiet', 'add', source, 'nested')
    git(work, 'commit', '--quiet', '--message', 'add submodule')
  end

  def write(work, files)
    files.each { |name, body| File.write(File.join(work, name), body) }
  end

  def in_repository
    Dir.mktmpdir('shaka-snapshot-test') do |root|
      work = File.join(root, 'work')
      git(root, 'init', '--quiet', '--bare', File.join(root, 'origin'))
      git(root, 'init', '--quiet', work)
      seed(work, File.join(root, 'origin'))
      yield work
    end
  end

  def seed(work, origin)
    git(work, 'config', 'user.email', 'test@example.com')
    git(work, 'config', 'user.name', 'Test')
    File.write(File.join(work, 'README.md'), "base\n")
    git(work, 'add', '--all')
    git(work, 'commit', '--quiet', '--message', 'base')
    git(work, 'remote', 'add', 'origin', origin)
    git(work, 'checkout', '--quiet', '-b', 'feature')
  end

  def git(directory, *argv)
    output, error, status = Open3.capture3('git', '-C', directory, *argv)
    raise "git #{argv.first} failed: #{error}" unless status.success?

    output
  end
end

# The snapshot must publish real work without disturbing the checkout it came from.
class SnapshotTest < Minitest::Test
  include SnapshotRepository

  def test_it_plans_without_publishing_until_asked
    in_repository do |work|
      write(work, 'research.md' => "half an idea\n")

      report = run_snapshot(work)

      assert_equal [false, ['research.md']], report.values_at('published', 'adds')
      assert_empty remote_branches(work)
    end
  end

  def test_it_publishes_unfinished_work_and_leaves_the_checkout_alone
    in_repository do |work|
      write(work, 'README.md' => "base\nmore\n", 'research.md' => "half an idea\n", 'api_key.txt' => "nope\n")

      report = run_snapshot(work, '--push')

      assert_equal ['wip/feature', true, ['README.md', 'research.md'], ['api_key.txt']],
                   report.values_at('branch', 'published', 'adds', 'held_back')
      assert_equal "half an idea\n", File.read(File.join(work, 'research.md'))
      assert_includes git(work, 'status', '--porcelain'), 'M README.md'
    end
  end

  def test_a_pending_rename_and_a_deletion_survive_the_snapshot
    in_repository do |work|
      write(work, 'beta.txt' => "two\n")
      git(work, 'add', '--all')
      git(work, 'commit', '--quiet', '--message', 'second')
      git(work, 'mv', 'README.md', 'moved.md')
      File.delete(File.join(work, 'beta.txt'))

      report = run_snapshot(work, '--push')

      assert_equal [['moved.md'], ['README.md', 'beta.txt']], report.values_at('adds', 'removes')
      assert_equal ['moved.md'], published_files(work, report['commit'])
    end
  end

  def test_an_untracked_embedded_repository_is_held_back
    in_repository do |work|
      embedded = File.join(work, 'embedded')
      Dir.mkdir(embedded)
      git(embedded, 'init', '--quiet', embedded)
      File.write(File.join(embedded, 'inner.md'), "nested work\n")

      report = run_snapshot(work)

      assert_equal ['embedded/'], report['held_back_submodules']
      assert_empty report['adds']
    end
  end

  def test_a_seam_that_cannot_be_read_refuses_to_publish
    in_repository do |work|
      write(work, 'research.md' => "half an idea\n")
      Dir.mkdir(File.join(work, '.agents'))
      File.write(File.join(work, '.agents/agent-workflow.yml'), "---\nrecovery:\n  snapshot: false\n")

      result = nil
      Dir.chdir(work) { capture_io { result = Shaka::Snapshot.run(['--push']) } }

      assert_equal 1, result
      assert_empty remote_branches(work)
    end
  end

  def test_a_file_reported_deleted_but_still_on_disk_is_published
    in_repository do |work|
      write(work, 'conflicted.md' => "one side survived\n")

      plan = Shaka::Snapshot::Plan.new(root: work, branch: 'wip/feature', remote_head: '',
                                       git: ->(*argv) { git(work, *argv) }).to_h

      assert_includes plan['adds'], 'conflicted.md'
    end
  end

  def test_a_clean_checkout_publishes_nothing
    in_repository do |work|
      report = run_snapshot(work, '--push')

      assert_nil report['branch']
      assert_empty report['adds']
    end
  end
end

# Snapshots must work from anywhere in a checkout, and never overstate a submodule.
class SnapshotBoundaryTest < Minitest::Test
  include SnapshotRepository

  def test_it_runs_from_a_subdirectory
    in_repository do |work|
      Dir.mkdir(File.join(work, 'sub'))
      write(work, 'README.md' => "base\nmore\n", 'sub/nested.md' => "deep\n")

      report = run_snapshot(File.join(work, 'sub'), '--push')

      assert_equal ['README.md', 'sub/nested.md'], report['adds']
      assert_equal ['README.md', 'sub/nested.md'], published_files(work, report['commit'])
    end
  end

  def test_edits_inside_a_submodule_are_held_back_rather_than_claimed
    in_repository do |work|
      add_submodule(work)
      File.write(File.join(work, 'nested', 'README.md'), "changed inside\n")

      report = run_snapshot(work)

      assert_equal ['nested'], report['held_back_submodules']
      refute_includes report['adds'], 'nested'
    end
  end
end

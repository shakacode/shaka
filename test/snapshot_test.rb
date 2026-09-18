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

  def test_deleted_files_are_removed_rather_than_added
    changes = Shaka::Snapshot::Changes.new([' D beta.txt', '?? delta.txt', ' M kept.txt'])

    assert_equal ['delta.txt', 'kept.txt'], changes.added
    assert_equal ['beta.txt'], changes.removed
  end
end

# The snapshot must publish real work without disturbing the checkout it came from.
class SnapshotTest < Minitest::Test
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

  def test_a_clean_checkout_publishes_nothing
    in_repository do |work|
      report = run_snapshot(work, '--push')

      assert_nil report['branch']
      assert_empty report['adds']
    end
  end

  private

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

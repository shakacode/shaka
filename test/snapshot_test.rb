# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'fileutils'
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

  def test_environment_files_are_held_back_whatever_their_case_or_prefix
    paths = ['staging.env', 'service.ENV', '.Env.local', 'config/BACKEND.env', 'certs/server.PEM']
    screen = Shaka::Snapshot::Screen.new(paths)

    assert_empty screen.included
  end

  def test_a_credential_directory_holds_back_what_it_contains
    paths = ['credentials/github.yml', 'app/service_account/key.json', 'config/secrets/master.txt']
    screen = Shaka::Snapshot::Screen.new(paths)

    assert_empty screen.included
  end

  # A keyword ending a longer name, which anchoring at the segment start used to miss.
  def test_credential_names_are_held_back_wherever_the_word_sits
    paths = ['aws_credentials.json', 'db-credentials.yml', 'my-project-service-account.json']
    screen = Shaka::Snapshot::Screen.new(paths)

    assert_empty screen.included
  end

  # The names reviewers found missing, each one a real credential file in the wild.
  def test_well_known_credential_files_are_held_back
    paths = ['terraform.tfstate', 'infra/terraform.tfstate.backup', 'kubeconfig',
             '.kube/config', 'keys/firebase-adminsdk-a1b2c.json', 'gcp-serviceaccount.json']
    screen = Shaka::Snapshot::Screen.new(paths)

    assert_empty screen.included
  end

  def test_an_environment_directory_holds_back_what_it_contains
    paths = ['env/database.yml', '.env/production.yml', 'config/env/settings.yml']
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

# The repositories these tests need: a seam, a submodule, a merge, a second remote.
module SnapshotFixtures
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

  # A seam the schema accepts, so the recovery setting itself decides the outcome.
  def write_seam(work, snapshot:)
    Dir.mkdir(File.join(work, '.agents'))
    Dir.mkdir(File.join(work, '.agents/bin'))
    %w[setup validate test].each do |name|
      path = File.join(work, '.agents/bin', name)
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)
    end
    template = File.read(File.expand_path('fixtures/snapshot_seam.yml', __dir__))
    File.write(File.join(work, '.agents/agent-workflow.yml'), format(template, snapshot: snapshot))
    publish_seam(work)
  end

  # A branch whose own seam allows snapshots and names itself as the base.
  def add_permissive_branch(work)
    git(work, 'checkout', '--quiet', '-b', 'permissive')
    template = File.read(File.expand_path('fixtures/snapshot_seam.yml', __dir__))
    File.write(File.join(work, '.agents/agent-workflow.yml'),
               format(template, snapshot: true).sub('base_branch: main', 'base_branch: permissive'))
    commit_all(work, 'permissive seam')
    git(work, 'push', '--quiet', 'origin', 'HEAD:refs/heads/permissive')
  end

  # The policy reads the seam from the trusted remote branch, so the fixture lives there.
  def publish_seam(work)
    commit_all(work, 'seam')
    git(work, 'push', '--quiet', 'origin', 'HEAD:refs/heads/main')
    git(work, 'fetch', '--quiet', 'origin')
  end

  # The credential exists only in the merge commit, so no parent's diff ever names it.
  def merge_that_adds_credentials(work)
    git(work, 'checkout', '--quiet', '-b', 'side')
    write(work, 'side.md' => "side\n")
    commit_all(work, 'side')
    git(work, 'checkout', '--quiet', 'feature')
    git(work, 'merge', '--quiet', '--no-ff', '--no-commit', 'side')
    Dir.mkdir(File.join(work, 'config'))
    write(work, 'config/credentials.json' => "{}\n")
    commit_all(work, 'merge')
  end

  # A second remote holding this branch, so reachability cannot be read from all remotes.
  def elsewhere(work)
    other = File.join(File.dirname(work), 'elsewhere')
    git(File.dirname(work), 'init', '--quiet', '--bare', '--initial-branch', 'main', other)
    git(work, 'remote', 'add', 'elsewhere', other)
    git(work, 'push', '--quiet', 'elsewhere', 'HEAD:refs/heads/feature')
    git(work, 'fetch', '--quiet', 'elsewhere')
  end
end

# Builds a throwaway repository so the snapshot runs against real git.
module SnapshotRepository
  include SnapshotFixtures

  def run_snapshot(work, *arguments)
    output = nil
    isolated { Dir.chdir(work) { output = capture_io { assert_equal 0, Shaka::Snapshot.new(arguments).run }.first } }
    JSON.parse(output)
  end

  # Publishing confirms the plan that was read, so the digest comes from a planning run.
  def publish_snapshot(work)
    digest = run_snapshot(work).fetch('digest')
    run_snapshot(work, '--push', '--expect', digest)
  end

  def published_files(work, commit)
    git(work, 'ls-tree', '--name-only', '-r', commit).split("\n").sort
  end

  def remote_branches(work)
    git(work, 'ls-remote', '--heads', 'origin').split("\n")
  end

  def remote_branches_of(work, url)
    git(work, 'ls-remote', '--heads', url).split("\n")
  end

  def push_snapshot(work, digest, *extra)
    result = nil
    isolated { Dir.chdir(work) { capture_io { result = Shaka::Snapshot.run(['--push', '--expect', digest] + extra) } } }
    result
  end

  # A checkout on a named branch that has no commits yet, and a remote to refuse or accept.
  def in_unborn_repository
    Dir.mktmpdir('shaka-snapshot-test') do |root|
      work = File.join(root, 'work')
      git(root, 'init', '--quiet', '--bare', '--initial-branch', 'main', File.join(root, 'origin'))
      git(root, 'init', '--quiet', '--initial-branch', 'feature', work)
      git(work, 'config', 'user.email', 'test@example.com')
      git(work, 'remote', 'add', 'origin', File.join(root, 'origin'))
      yield work
    end
  end

  # The refusal paths report through stderr, which the JSON reader cannot see.
  def run_failing(work, *arguments)
    error = nil
    isolated { Dir.chdir(work) { error = capture_io { Shaka::Snapshot.run(arguments) }.last } }
    error
  end

  def without_identity(work, *fields)
    fields.each { |field| git(work, 'config', '--unset', field) }
    git(work, 'config', 'user.useConfigOnly', 'true')
    write(work, 'research.md' => "half an idea\n")
  end

  def commit_all(work, message)
    git(work, 'add', '--all')
    git(work, 'commit', '--quiet', '--message', message)
  end

  def write(work, files)
    files.each { |name, body| File.write(File.join(work, name), body) }
  end

  # The origin names `main` as its HEAD, as a real remote does. Without that the bare
  # repository's HEAD dangles at whatever `init.defaultBranch` says, which the policy
  # refuses, and the test would pass or fail with the machine's git configuration.
  def in_repository
    Dir.mktmpdir('shaka-snapshot-test') do |root|
      work = File.join(root, 'work')
      git(root, 'init', '--quiet', '--bare', '--initial-branch', 'main', File.join(root, 'origin'))
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

  # The machine's own git configuration must not decide what these tests prove. A global
  # ignore rule, a default branch name, or a configured identity would otherwise make a
  # fixture mean something different here than it does on a runner.
  ISOLATED = { 'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_SYSTEM' => File::NULL }.freeze

  def git(directory, *argv, index: nil)
    environment = ISOLATED.merge(index ? { 'GIT_INDEX_FILE' => index } : {})
    output, error, status = Open3.capture3(environment, 'git', '-C', directory, *argv)
    raise "git #{argv.first} failed: #{error}" unless status.success?

    output
  end

  # The command shells out to git itself, so it needs the same isolation.
  def isolated
    previous = ENV.to_h.slice(*ISOLATED.keys)
    ENV.update(ISOLATED)
    yield
  ensure
    ISOLATED.each_key { |key| ENV.delete(key) }
    ENV.update(previous)
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

      report = publish_snapshot(work)

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

      report = publish_snapshot(work)

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
      isolated { Dir.chdir(work) { capture_io { result = Shaka::Snapshot.run(['--push']) } } }

      assert_equal 1, result
      assert_empty remote_branches(work)
    end
  end

  # A delete/modify conflict resolved to a symlink, which the status still calls deleted.
  # Git reports path bytes, and a checkout may hold a name that is not valid UTF-8.
  def test_a_path_that_is_not_valid_utf8_is_planned_rather_than_raising
    in_repository do |work|
      runner = ->(*argv, **rest) { argv.first == 'status' ? "?? bad\xFFname\0".b : git(work, *argv, **rest) }

      plan = Shaka::Snapshot::Plan.new(root: work, branch: 'wip/feature', remote_head: '',
                                       git: runner).to_h

      assert_equal [[], ['bad?name']], plan.values_at('adds', 'held_back')
    end
  end

  def test_a_conflict_resolved_to_a_symlink_is_published
    in_repository do |work|
      File.symlink('missing-target', File.join(work, 'link'))
      runner = ->(*argv, **rest) { argv.first == 'status' ? "UD link\0" : git(work, *argv, **rest) }

      plan = Shaka::Snapshot::Plan.new(root: work, branch: 'wip/feature', remote_head: '',
                                       git: runner).to_h

      assert_equal [['link'], []], plan.values_at('adds', 'removes')
    end
  end

  def test_a_file_reported_deleted_but_still_on_disk_is_published
    in_repository do |work|
      write(work, 'conflicted.md' => "one side survived\n")

      runner = ->(*argv, index: nil) { git(work, *argv, index: index) }
      plan = Shaka::Snapshot::Plan.new(root: work, branch: 'wip/feature', remote_head: '',
                                       git: runner).to_h

      assert_includes plan['adds'], 'conflicted.md'
    end
  end

  def test_publishing_without_the_plan_digest_is_refused
    in_repository do |work|
      write(work, 'research.md' => "half an idea\n")

      result = nil
      isolated { Dir.chdir(work) { capture_io { result = Shaka::Snapshot.run(['--push']) } } }

      assert_equal 1, result
      assert_empty remote_branches(work)
    end
  end

  def test_a_changed_checkout_invalidates_the_plan_digest
    in_repository do |work|
      write(work, 'research.md' => "half an idea\n")
      digest = run_snapshot(work).fetch('digest')
      write(work, 'later.md' => "arrived after the plan\n")

      result = nil
      isolated { Dir.chdir(work) { capture_io { result = Shaka::Snapshot.run(['--push', '--expect', digest]) } } }

      assert_equal 1, result
      assert_empty remote_branches(work)
    end
  end
end

# The pushed branch carries the local history, not only the working tree.
class SnapshotHistoryTest < Minitest::Test
  include SnapshotRepository

  # The snapshot carries no history, so a local commit stays where it is and gets named.
  def test_local_commits_are_named_rather_than_published
    in_repository do |work|
      git(work, 'push', '--quiet', 'origin', 'HEAD:refs/heads/feature')
      write(work, 'research.md' => "half an idea\n")
      commit_all(work, 'research')

      report = run_snapshot(work)

      assert_equal [[], 1], [report['adds'], report['unpushed_commits'].length]
      assert_nil report['branch']
    end
  end

  # A credential committed locally cannot reach the remote, because no history travels.
  def test_a_credential_in_a_local_commit_does_not_travel
    in_repository do |work|
      Dir.mkdir(File.join(work, 'config'))
      write(work, 'config/credentials.json' => "{}\n")
      commit_all(work, 'credentials')
      write(work, 'research.md' => "half an idea\n")

      report = publish_snapshot(work)

      assert_equal ['research.md'], published_files(work, report['commit'])
    end
  end

  def test_a_credential_added_by_a_merge_resolution_does_not_travel
    in_repository do |work|
      merge_that_adds_credentials(work)
      write(work, 'research.md' => "half an idea\n")

      report = publish_snapshot(work)

      assert_equal ['research.md'], published_files(work, report['commit'])
    end
  end

  # The one property every history finding reduces to: the commit has no ancestry at all.
  def test_the_published_commit_has_no_parent
    in_repository do |work|
      write(work, 'research.md' => "half an idea\n")

      report = publish_snapshot(work)

      assert_empty git(work, 'rev-list', '--parents', '-1', report['commit']).split[1..]
    end
  end

  # Planning reads nothing the remote must answer, so it survives a remote that is down.
  def test_planning_works_while_the_remote_is_unreachable
    in_repository do |work|
      git(work, 'remote', 'set-url', 'origin', File.join(work, 'missing.git'))
      write(work, 'research.md' => "half an idea\n")

      assert_equal ['research.md'], run_snapshot(work)['adds']
    end
  end

  # A status path is a name on disk, not a pattern: `:(top,glob)**` names one file.
  def test_a_filename_that_looks_like_a_pathspec_publishes_only_itself
    in_repository do |work|
      write(work, '.gitignore' => "secret.env\n")
      commit_all(work, 'ignore')
      write(work, 'secret.env' => "SECRET=1\n", ':(top,glob)**' => "odd\n")

      report = publish_snapshot(work)

      assert_equal [':(top,glob)**'], published_files(work, report['commit'])
    end
  end

  # Drafts in a repository that has never committed are exactly what this is for.
  def test_a_repository_without_its_first_commit_can_still_snapshot
    in_unborn_repository do |work|
      write(work, 'research.md' => "half an idea\n")

      report = publish_snapshot(work)

      assert_equal ['research.md'], published_files(work, report['commit'])
    end
  end

  # A remote name beginning with a dash is an option to git, not a place to push.
  def test_a_remote_that_looks_like_an_option_is_refused
    in_repository do |work|
      write(work, 'research.md' => "half an idea\n")

      assert_includes run_failing(work, '--remote=--receive-pack=/tmp/evil'), 'cannot begin with a dash'
    end
  end

  def test_a_checkout_without_a_git_identity_still_publishes
    in_repository do |work|
      without_identity(work, 'user.email', 'user.name')

      assert_equal true, publish_snapshot(work)['published']
    end
  end

  # Git needs both fields, so half a configuration must not read as a whole one.
  def test_a_checkout_with_only_half_an_identity_still_publishes
    in_repository do |work|
      without_identity(work, 'user.name')

      assert_equal true, publish_snapshot(work)['published']
    end
  end

  # Clean means the remote already holds it, not merely that nothing is uncommitted.
  def test_a_checkout_the_remote_already_holds_publishes_nothing
    in_repository do |work|
      git(work, 'push', '--quiet', 'origin', 'HEAD:refs/heads/feature')

      report = run_snapshot(work, '--push')

      assert_nil report['branch']
      assert_empty report['adds']
    end
  end
end

# Snapshots must work from anywhere in a checkout, and never overstate a submodule.
class SnapshotBoundaryTest < Minitest::Test
  include SnapshotRepository

  def test_deleting_the_local_seam_does_not_escape_the_trusted_setting
    in_repository do |work|
      write_seam(work, snapshot: false)
      File.delete(File.join(work, '.agents/agent-workflow.yml'))
      write(work, 'research.md' => "half an idea\n")

      result = nil
      isolated { Dir.chdir(work) { capture_io { result = Shaka::Snapshot.run(['--push', '--expect', 'anything']) } } }

      assert_equal 1, result
      refute_includes remote_branches(work).join, 'wip/'
    end
  end

  def test_a_redirected_base_branch_cannot_choose_the_trusted_copy
    in_repository do |work|
      write_seam(work, snapshot: false)
      add_permissive_branch(work)
      write(work, 'research.md' => "half an idea\n")

      result = nil
      isolated { Dir.chdir(work) { capture_io { result = Shaka::Snapshot.run(['--push', '--expect', 'anything']) } } }

      assert_equal 1, result
      refute_includes remote_branches(work).join, 'wip/'
    end
  end

  def test_a_seam_that_allows_snapshots_still_publishes
    in_repository do |work|
      write_seam(work, snapshot: true)
      write(work, 'research.md' => "half an idea\n")

      assert_equal true, publish_snapshot(work)['published']
    end
  end

  def test_a_seam_that_disables_snapshots_refuses_to_publish
    in_repository do |work|
      write_seam(work, snapshot: false)
      write(work, 'research.md' => "half an idea\n")

      result = nil
      isolated { Dir.chdir(work) { capture_io { result = Shaka::Snapshot.run(['--push', '--expect', 'anything']) } } }

      assert_equal 1, result
      refute_includes remote_branches(work).join, 'wip/'
    end
  end

  def test_it_runs_from_a_subdirectory
    in_repository do |work|
      Dir.mkdir(File.join(work, 'sub'))
      write(work, 'README.md' => "base\nmore\n", 'sub/nested.md' => "deep\n")

      report = publish_snapshot(File.join(work, 'sub'))

      assert_equal ['README.md', 'sub/nested.md'], report['adds']
      assert_equal ['README.md', 'sub/nested.md'], published_files(work, report['commit'])
    end
  end

  def test_a_directory_that_replaced_a_deleted_file_publishes_no_ignored_children
    in_repository do |work|
      write(work, 'notes' => "one file\n", '.gitignore' => "notes/cache\n")
      commit_all(work, 'notes')
      File.delete(File.join(work, 'notes'))
      Dir.mkdir(File.join(work, 'notes'))
      write(work, 'notes/keep.md' => "still working\n", 'notes/cache' => "generated\n")

      report = publish_snapshot(work)

      assert_equal [['notes/keep.md'], ['notes']], report.values_at('adds', 'removes')
      assert_equal ['notes/keep.md'], published_files(work, report['commit'])
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

# The remote alone answers whether unfinished work may leave the machine.
class SnapshotPolicyTest < Minitest::Test
  include SnapshotRepository

  TIP = '1111111111111111111111111111111111111111'
  LISTING = "ref: refs/heads/main\tHEAD\n#{TIP}\tHEAD\n#{TIP}\trefs/heads/main\n".freeze

  def test_a_failed_fetch_is_not_read_as_a_repository_without_a_seam
    git = stub_remote('ls-remote --symref origin' => LISTING,
                      'fetch --quiet origin refs/heads/main' => Shaka::Error.new('could not read from remote'))

    policy = Shaka::Snapshot::Policy.new(root: Dir.pwd, remote: 'origin', git:)

    assert_raises(Shaka::Error) { policy.allows_snapshot? }
  end

  def test_a_default_branch_without_a_seam_keeps_the_default
    git = stub_remote('ls-remote --symref origin' => LISTING,
                      'fetch --quiet origin refs/heads/main' => '',
                      "ls-tree #{TIP} -- .agents/agent-workflow.yml" => "\n")

    policy = Shaka::Snapshot::Policy.new(root: Dir.pwd, remote: 'origin', git:)

    assert_equal true, policy.allows_snapshot?
  end

  def test_a_remote_with_branches_but_no_advertised_head_refuses
    git = stub_remote('ls-remote --symref origin' => "#{TIP}\trefs/heads/main\n")

    policy = Shaka::Snapshot::Policy.new(root: Dir.pwd, remote: 'origin', git:)

    assert_raises(Shaka::Error) { policy.allows_snapshot? }
  end

  def test_a_remote_advertising_only_a_tag_must_still_name_its_default_branch
    git = stub_remote('ls-remote --symref origin' => "#{TIP}\trefs/tags/v1\n")

    policy = Shaka::Snapshot::Policy.new(root: Dir.pwd, remote: 'origin', git:)

    assert_raises(Shaka::Error) { policy.allows_snapshot? }
  end

  def test_a_remote_that_advertises_nothing_keeps_the_default
    git = stub_remote('ls-remote --symref origin' => "\n")
    policy = Shaka::Snapshot::Policy.new(root: Dir.pwd, remote: 'origin', git:)

    assert_equal true, policy.allows_snapshot?
  end

  # A target named by path or URL is the one that gets the push, so it answers for itself.
  def test_a_remote_named_by_path_answers_for_itself
    in_repository do |work|
      write_seam(work, snapshot: false)
      origin = git(work, 'remote', 'get-url', 'origin').strip
      git(work, 'remote', 'remove', 'origin')
      write(work, 'research.md' => "half an idea\n")

      result = push_snapshot(work, 'anything', '--remote', origin)

      assert_equal 1, result
      refute_includes remote_branches_of(work, origin).join, 'wip/'
    end
  end

  def test_the_remote_seam_decides_although_the_checkout_lacks_its_commands
    in_repository do |work|
      write_seam(work, snapshot: true)
      FileUtils.rm_rf(File.join(work, '.agents/bin'))
      write(work, 'research.md' => "half an idea\n")

      assert_equal true, publish_snapshot(work)['published']
    end
  end

  private

  # Every answer is spelled out, so an unexpected command fails rather than passing quietly.
  def stub_remote(answers)
    lambda do |*argv|
      answer = answers.fetch(argv.join(' ')) { raise Shaka::Error, "unexpected git #{argv.join(' ')}" }
      raise answer if answer.is_a?(Shaka::Error)

      answer
    end
  end
end

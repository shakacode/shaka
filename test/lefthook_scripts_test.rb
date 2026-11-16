# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'tmpdir'

# Runs the bin/lefthook scripts the commit hooks call, in a scratch directory.
module LefthookScriptHelpers
  ROOT = File.expand_path('..', __dir__)
  ENVIRONMENT = { 'BUNDLE_GEMFILE' => File.join(ROOT, 'Gemfile'), 'RUBYOPT' => nil, 'RUBYLIB' => nil,
                  'GIT_CONFIG_GLOBAL' => File::NULL, 'GIT_CONFIG_NOSYSTEM' => '1', 'SHAKA_BASE_REF' => nil }.freeze

  def setup
    @dir = Dir.mktmpdir
    write('.rubocop.yml', "AllCops:\n  NewCops: enable\n  SuggestExtensions: false\n  TargetRubyVersion: 3.4\n")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  private

  def script(name, *, stdin_data: '', env: {})
    Open3.capture2e(ENVIRONMENT.merge(env), RbConfig.ruby, File.join(ROOT, 'bin/lefthook', name), *,
                    chdir: @dir, stdin_data:)
  end

  def git(*)
    output, status = Open3.capture2e(ENVIRONMENT, 'git', '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
                                     '-c', 'commit.gpgsign=false', *, chdir: @dir)
    assert_predicate status, :success?, output
    output
  end

  # Puts an executable shell script named name first on PATH and returns that PATH.
  def stub_command(name, body)
    bin = File.join(@dir, '.git', 'stub-bin')
    FileUtils.mkdir_p(bin)
    File.write(File.join(bin, name), "#!/bin/sh\n#{body}\n")
    File.chmod(0o755, File.join(bin, name))
    [bin, ENV.fetch('PATH')].join(File::PATH_SEPARATOR)
  end

  def git_repository
    git('init', '-q')
    git('add', '.')
    git('commit', '-qm', 'base')
    git('update-ref', 'refs/remotes/origin/main', 'HEAD')
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(@dir, path)))
    File.binwrite(File.join(@dir, path), content)
  end

  def read(path) = File.binread(File.join(@dir, path))
end

class LefthookScriptsTest < Minitest::Test
  include LefthookScriptHelpers

  def test_rejects_a_ruby_syntax_error
    write('broken.rb', "# frozen_string_literal: true\n\ndef broken\n  1\n")
    output, status = script('ruby-check', 'fix', 'broken.rb')

    refute_predicate status, :success?
    assert_includes output, 'Syntax errors in: broken.rb'
  end

  def test_rejects_an_offence_rubocop_cannot_fix
    write('lint.rb', "# frozen_string_literal: true\n\ndef lintMe = 1\n")
    output, status = script('ruby-check', 'fix', 'lint.rb')

    refute_predicate status, :success?
    assert_includes output, 'Naming/MethodName'
  end

  def test_fix_mode_corrects_what_rubocop_can_and_passes
    write('quotes.rb', "# frozen_string_literal: true\n\nputs \"plain\"\n")
    _, status = script('ruby-check', 'fix', 'quotes.rb')

    assert_predicate status, :success?
    assert_equal "# frozen_string_literal: true\n\nputs 'plain'\n", read('quotes.rb')
  end

  def test_lint_mode_reports_without_changing_files
    original = "# frozen_string_literal: true\n\nputs \"plain\"\n"
    write('quotes.rb', original)
    _, status = script('ruby-check', 'lint', 'quotes.rb')

    refute_predicate status, :success?
    assert_equal original, read('quotes.rb')
  end

  def test_checks_extensionless_ruby_scripts_and_skips_other_files
    write('tool', "#!/usr/bin/env ruby\nputs(\n")
    write('Rakefile', "task(\n")
    write('notes.md', "puts(\n")
    write('run.sh', "#!/bin/sh\nputs(\n")
    output, status = script('ruby-check', 'fix', 'tool', 'Rakefile', 'notes.md', 'run.sh', 'deleted.rb')

    refute_predicate status, :success?
    assert_includes output, 'Syntax errors in: tool, Rakefile'
    _, others = script('ruby-check', 'fix', 'notes.md', 'run.sh')

    assert_predicate others, :success?
  end

  def test_trailing_newlines_adds_only_missing_text_newlines
    write('a.txt', 'text')
    write('b.txt', "done\n")
    write('c.bin', "bin\0ary")
    write('d.bin', "\x08\x01")
    write('e.txt', '')
    _, status = script('trailing-newlines', 'a.txt', 'b.txt', 'c.bin', 'd.bin', 'e.txt', 'missing.txt')

    assert_predicate status, :success?
    assert_equal(["text\n", "done\n", "bin\0ary", "\x08\x01", ''], %w[a.txt b.txt c.bin d.bin e.txt].map { read(it) })
  end

  def test_trailing_newlines_leaves_symlink_targets_alone
    skip 'Creating symlinks needs extra privileges on Windows' if Gem.win_platform?

    Dir.mktmpdir do |outside|
      target = File.join(outside, 'target.txt')
      File.binwrite(target, 'outside')
      File.symlink(target, File.join(@dir, 'link.txt'))
      _, status = script('trailing-newlines', 'link.txt')

      assert_predicate status, :success?
      assert_equal 'outside', File.binread(target)
    end
  end

  def test_reports_when_rubocop_cannot_run
    write('ok.rb', "# frozen_string_literal: true\n\nputs 'ok'\n")
    output, status = script('ruby-check', 'lint', 'ok.rb', env: { 'PATH' => File.join(@dir, 'no-bin') })

    refute_predicate status, :success?
    assert_includes output, 'RuboCop could not run'
  end

  def test_installed_reports_whether_the_pre_commit_hook_runs_lefthook
    git('init', '-q')

    refute_predicate script('installed').last, :success?
    write('.git/hooks/pre-commit', "#!/bin/sh\nlefthook run pre-commit \"$@\"\n")

    assert_predicate script('installed').last, :success?
  end
end

# Runs the pre-push check against commits in a scratch repository.
class LefthookBranchCheckTest < Minitest::Test
  include LefthookScriptHelpers

  def test_branch_mode_checks_committed_content_not_the_working_tree
    git_repository
    write('lib/a.rb', "# frozen_string_literal: true\n\ndef broken\n")
    git('add', '.')
    git('commit', '-qm', 'broken')
    write('lib/a.rb', "# frozen_string_literal: true\n\nputs 'fixed'\n")
    output, status = script('ruby-check', 'branch')

    refute_predicate status, :success?
    assert_includes output, 'Syntax errors in: lib/a.rb'
    assert_equal "# frozen_string_literal: true\n\nputs 'fixed'\n", read('lib/a.rb')
  end

  def test_branch_mode_checks_the_pushed_ref_and_ignores_unpushed_edits
    git_repository
    write('lib/a.rb', "# frozen_string_literal: true\n\nputs 'clean'\n")
    git('add', '.')
    git('commit', '-qm', 'clean')
    pushed = git('rev-parse', 'HEAD').strip
    write('lib/a.rb', "def broken\n")
    input = "refs/heads/x #{pushed} refs/heads/x #{'0' * 40}\n"

    assert_predicate script('ruby-check', 'branch', stdin_data: input).last, :success?
  end

  def test_branch_mode_checks_nothing_for_a_deletion_push
    git_repository
    write('lib/a.rb', "def broken\n")
    git('add', '.')
    git('commit', '-qm', 'broken')
    input = "(delete) #{'0' * 40} refs/heads/old #{git('rev-parse', 'HEAD').strip}\n"

    assert_predicate script('ruby-check', 'branch', stdin_data: input).last, :success?
  end

  def test_branch_mode_runs_rubocop_with_the_committed_ruby_version
    skip 'The stub command is a shell script' if Gem.win_platform?

    write('.ruby-version', "3.4.6\n")
    git_repository
    write('lib/a.rb', "# frozen_string_literal: true\n\nputs 'clean'\n")
    git('add', '.')
    git('commit', '-qm', 'clean')
    record = File.join(@dir, '.git', 'seen-ruby-version')
    path = stub_command('bundle', "cat .ruby-version > '#{record}'")

    assert_predicate script('ruby-check', 'branch', env: { 'PATH' => path }).last, :success?
    assert_equal "3.4.6\n", File.read(record)
  end

  def test_branch_mode_fails_when_the_commit_cannot_be_extracted
    skip 'The stub command is a shell script' if Gem.win_platform?

    git_repository
    # Exceed the pipe buffer so a tar process that exits without reading forces a broken pipe.
    write('lib/a.rb', "# archive padding\n" * 65_536)
    git('add', '.')
    git('commit', '-qm', 'clean')
    output, status = script('ruby-check', 'branch', env: { 'PATH' => stub_command('tar', 'exit 1') })

    refute_predicate status, :success?
    assert_includes output, 'could not read the files of HEAD'
    refute_includes output, 'Errno::EPIPE'
  end
end

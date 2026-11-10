# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'tmpdir'

# Runs the bin/lefthook scripts the commit hooks call, in a scratch directory.
class LefthookScriptsTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  ENVIRONMENT = { 'BUNDLE_GEMFILE' => File.join(ROOT, 'Gemfile'), 'RUBYOPT' => nil, 'RUBYLIB' => nil }.freeze

  def setup
    @dir = Dir.mktmpdir
    write('.rubocop.yml', "AllCops:\n  NewCops: enable\n  SuggestExtensions: false\n  TargetRubyVersion: 3.4\n")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

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
    write('notes.md', "puts(\n")
    write('run.sh', "#!/bin/sh\nputs(\n")
    output, status = script('ruby-check', 'fix', 'tool', 'notes.md', 'run.sh', 'deleted.rb')

    refute_predicate status, :success?
    assert_includes output, 'Syntax errors in: tool'
    assert_predicate(*script('ruby-check', 'fix', 'notes.md', 'run.sh').values_at(1), :success?)
  end

  def test_trailing_newlines_adds_only_missing_text_newlines
    write('a.txt', 'text')
    write('b.txt', "done\n")
    write('c.bin', "bin\0ary")
    write('d.txt', '')
    _, status = script('trailing-newlines', 'a.txt', 'b.txt', 'c.bin', 'd.txt', 'missing.txt')

    assert_predicate status, :success?
    assert_equal(["text\n", "done\n", "bin\0ary", ''], %w[a.txt b.txt c.bin d.txt].map { read(it) })
  end

  def test_installed_reports_whether_the_pre_commit_hook_runs_lefthook
    system('git', 'init', '-q', @dir, exception: true)

    refute_predicate script('installed').last, :success?
    write('.git/hooks/pre-commit', "#!/bin/sh\nlefthook run pre-commit \"$@\"\n")

    assert_predicate script('installed').last, :success?
  end

  private

  def script(name, *)
    Open3.capture2e(ENVIRONMENT, RbConfig.ruby, File.join(ROOT, 'bin/lefthook', name), *, chdir: @dir)
  end

  def write(path, content)
    FileUtils.mkdir_p(File.dirname(File.join(@dir, path)))
    File.binwrite(File.join(@dir, path), content)
  end

  def read(path) = File.binread(File.join(@dir, path))
end

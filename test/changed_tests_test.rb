# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/changed_tests'

class ChangedTestsTest < Minitest::Test
  FILES = {
    'skills/shaka/lib/shaka/alpha.rb' => "require_relative 'beta'\n",
    'skills/shaka/lib/shaka/beta.rb' => '',
    'skills/shaka/lib/shaka/gamma.rb' => '',
    'skills/shaka/lib/shaka/orphan.rb' => '',
    'skills/shaka/scripts/shaka.rb' => "require_relative '../lib/shaka/gamma'\n",
    'test/test_helper.rb' => "def shaka_command = 'skills/shaka/scripts/shaka'\n",
    'test/alpha_test.rb' => "require_relative 'test_helper'\nrequire 'shaka/alpha'\n",
    'test/beta_test.rb' => "require_relative '../skills/shaka/lib/shaka/beta'\n",
    'test/cli_support.rb' => "def run_helper = shaka_command\n",
    'test/cli_test.rb' => "require_relative 'test_helper'\nrequire_relative 'cli_support'\n",
    'test/configuration_boundary_test.rb' => "require_relative 'test_helper'\n"
  }.freeze

  def setup
    @root = Dir.mktmpdir('changed-tests')
    FILES.each do |path, source|
      FileUtils.mkdir_p(File.join(@root, File.dirname(path)))
      File.write(File.join(@root, path), source)
    end
    @selector = ChangedTests.new(@root)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_a_library_change_selects_the_tests_that_load_it_directly_or_transitively
    assert_equal %w[test/alpha_test.rb test/beta_test.rb test/configuration_boundary_test.rb],
                 @selector.tests_for([%w[M skills/shaka/lib/shaka/beta.rb]])
  end

  def test_a_file_the_helper_loads_selects_tests_that_start_the_helper
    assert_equal %w[test/cli_test.rb test/configuration_boundary_test.rb],
                 @selector.tests_for([%w[M skills/shaka/lib/shaka/gamma.rb]])
  end

  def test_a_changed_test_file_selects_itself
    assert_equal %w[test/alpha_test.rb], @selector.tests_for([%w[A test/alpha_test.rb]])
  end

  def test_changes_it_cannot_map_run_the_whole_suite
    [[%w[M test/test_helper.rb]], [%w[M Gemfile.lock]], [%w[M bin/run-tests]],
     [%w[M skills/shaka/lib/shaka/orphan.rb]], [%w[D skills/shaka/lib/shaka/beta.rb]],
     [%w[M docs/settings.md]], [%w[M test/alpha_test.rb], %w[M test/test_helper.rb]], []].each do |changes|
      assert_nil @selector.tests_for(changes), changes.inspect
    end
  end

  def test_changes_include_commits_uncommitted_edits_and_untracked_files
    git('init', '--quiet', '--initial-branch=main')
    git('add', '.')
    git('commit', '--quiet', '-m', 'base')
    git('switch', '--quiet', '-c', 'work')
    File.write(File.join(@root, 'skills/shaka/lib/shaka/alpha.rb'), "# committed\n", mode: 'a')
    git('commit', '--quiet', '-am', 'change')
    File.write(File.join(@root, 'skills/shaka/lib/shaka/beta.rb'), "# edited\n")
    File.write(File.join(@root, 'test/new_test.rb'), '')

    assert_equal [%w[A test/new_test.rb], %w[M skills/shaka/lib/shaka/alpha.rb],
                  %w[M skills/shaka/lib/shaka/beta.rb]], @selector.changes('main').sort
  end

  private

  def git(*)
    _, error, status = Open3.capture3('git', '-C', @root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
                                      '-c', 'commit.gpgsign=false', *)
    assert_predicate status, :success?, error
  end
end

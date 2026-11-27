# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'support/changed_tests'

# Builds a small repository for the selector to map.
module ChangedTestsFixture
  FILES = {
    'skills/shaka/lib/shaka/alpha.rb' => "require_relative 'beta'\n",
    'skills/shaka/lib/shaka/beta.rb' => "GUIDE = 'docs/guide.md'\n",
    'skills/shaka/lib/shaka/gamma.rb' => '',
    'skills/shaka/lib/shaka/orphan.rb' => '',
    'skills/shaka/lib/shaka/unused.rb' => '',
    'skills/shaka/scripts/shaka.rb' => "require_relative '../lib/shaka/gamma'\n",
    'test/test_helper.rb' => "def shaka_command = 'skills/shaka/scripts/shaka'\nSHAKA_COMMAND = shaka_command\n",
    'test/alpha_test.rb' => "require_relative 'test_helper'\nrequire 'shaka/alpha'\n",
    'test/beta_test.rb' => "require_relative '../skills/shaka/lib/shaka/beta'\n",
    'test/child_test.rb' => "system('ruby', '-rshaka/orphan', '-e', '')\n",
    'test/cli_support.rb' => "def run_helper = SHAKA_COMMAND\n",
    'test/cli_test.rb' => "require_relative 'test_helper'\nrequire_relative 'cli_support'\n",
    'test/configuration_boundary_test.rb' => "require_relative 'test_helper'\n",
    'test/docs_support.rb' => "GUIDE = 'docs/guide.md'\nFIGURE = 'img/flow.svg'\n",
    'test/docs_test.rb' => "require_relative 'docs_support'\n"
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

  def commit_fixture
    git('init', '--quiet', '--initial-branch=main')
    git('add', '.')
    git('commit', '--quiet', '-m', 'base')
    git('switch', '--quiet', '-c', 'work')
    Open3.capture2('git', '-C', @root, 'rev-parse', 'HEAD').first.strip
  end

  def git(*)
    _, error, status = Open3.capture3('git', '-C', @root, '-c', 'user.name=Test', '-c', 'user.email=test@example.com',
                                      '-c', 'commit.gpgsign=false', *)
    assert_predicate status, :success?, error
  end
end

class ChangedTestsTest < Minitest::Test
  include ChangedTestsFixture

  def test_a_library_change_selects_the_tests_that_load_it_directly_or_transitively
    assert_equal %w[test/alpha_test.rb test/beta_test.rb test/configuration_boundary_test.rb],
                 @selector.tests_for([%w[M skills/shaka/lib/shaka/beta.rb]])
  end

  def test_a_file_the_helper_loads_selects_tests_that_start_the_helper
    assert_equal %w[test/cli_test.rb test/configuration_boundary_test.rb],
                 @selector.tests_for([%w[M skills/shaka/lib/shaka/gamma.rb]])
  end

  def test_a_library_a_child_ruby_preloads_selects_the_test_that_starts_it
    assert_equal %w[test/child_test.rb test/configuration_boundary_test.rb],
                 @selector.tests_for([%w[M skills/shaka/lib/shaka/orphan.rb]])
  end

  def test_a_changed_test_file_selects_itself_and_the_tests_that_require_it
    File.write(File.join(@root, 'test/gamma_test.rb'), "require_relative 'alpha_test'\n")

    assert_equal %w[test/alpha_test.rb test/gamma_test.rb], @selector.tests_for([%w[A test/alpha_test.rb]])
  end

  def test_changes_it_cannot_map_run_the_whole_suite
    [[%w[M test/test_helper.rb]], [%w[M Gemfile.lock]], [%w[M bin/run-tests]],
     [%w[M skills/shaka/lib/shaka/unused.rb]], [%w[D skills/shaka/lib/shaka/beta.rb]],
     [%w[M test/alpha_test.rb], %w[M test/test_helper.rb]], [%w[T test/alpha_test.rb]], [%w[M eval/notes.md]],
     [%w[M skills/shaka/scripts/shaka]], []].each do |changes|
      assert_nil @selector.tests_for(changes), changes.inspect
    end
  end

  def test_a_deleted_library_file_selects_the_tests_that_still_load_it
    base = commit_fixture
    File.delete(File.join(@root, 'skills/shaka/lib/shaka/orphan.rb'))

    assert_equal %w[test/child_test.rb test/configuration_boundary_test.rb],
                 @selector.tests_for(@selector.files.changes('main'), base:)
  end

  def test_a_renamed_library_file_selects_the_tests_that_reached_it_at_the_base
    base = commit_fixture
    File.rename(File.join(@root, 'skills/shaka/lib/shaka/beta.rb'), File.join(@root, 'skills/shaka/lib/shaka/delta.rb'))
    File.write(File.join(@root, 'skills/shaka/lib/shaka/alpha.rb'), "require_relative 'delta'\n")
    File.write(File.join(@root, 'test/beta_test.rb'), "require_relative '../skills/shaka/lib/shaka/delta'\n")
    File.delete(File.join(@root, 'test/child_test.rb'))

    assert_equal %w[test/alpha_test.rb test/beta_test.rb test/configuration_boundary_test.rb],
                 @selector.tests_for(@selector.files.changes('main'), base:)
    assert_empty @selector.tests_for([%w[D test/child_test.rb]], base:)
  end

  def test_changes_include_commits_uncommitted_edits_and_untracked_files
    commit_fixture
    File.write(File.join(@root, 'skills/shaka/lib/shaka/alpha.rb'), "# committed\n", mode: 'a')
    git('commit', '--quiet', '-am', 'change')
    File.write(File.join(@root, 'skills/shaka/lib/shaka/beta.rb'), "# edited\n")
    File.write(File.join(@root, 'test/new_test.rb'), '')

    assert_equal [%w[A test/new_test.rb], %w[M skills/shaka/lib/shaka/alpha.rb],
                  %w[M skills/shaka/lib/shaka/beta.rb]], @selector.files.changes('main').sort
  end
end

class ChangedTestsDataTest < Minitest::Test
  include ChangedTestsFixture

  # skills/shaka/lib/shaka/beta.rb names the guide too, but library files do not read docs pages.
  def test_a_data_file_selects_the_tests_whose_test_files_name_it
    assert_equal %w[test/docs_test.rb], @selector.tests_for([%w[M docs/guide.md]])
  end

  def test_a_figure_selects_the_tests_that_name_it_and_no_others
    assert_equal %w[test/docs_test.rb], @selector.tests_for([%w[M docs/img/flow.svg]])
    assert_empty @selector.tests_for([%w[A docs/img/new.webp]])
  end

  def test_a_data_file_no_test_reads_selects_no_tests
    assert_empty @selector.tests_for([%w[M internal/notes.md], %w[A docs/new-guide.md], %w[D README.md]])
  end

  def test_skill_settings_instructions_and_unmapped_files_run_the_whole_suite
    [%w[M skills/shaka/config/defaults.yml], %w[A skills/shaka/references/guide.md],
     %w[M .agents/shaka/config.yml], %w[M AGENTS.md], %w[M internal/adr/diagram.svg]].each do |change|
      assert_nil @selector.tests_for([change]), change.inspect
    end
  end
end

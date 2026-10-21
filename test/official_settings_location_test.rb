# frozen_string_literal: true

require_relative 'install_scenario_support'

# HOME/.agents holds Shaka settings, so the installer refuses a source checkout there and names one command.
class OfficialSettingsLocationTest < Minitest::Test
  include InstallScenarioSupport

  def test_directories_under_the_settings_path_are_refused
    %w[.agents/shaka .agents/anything].each do |entry|
      directory = File.join(@home, entry)
      output, process = install(@root, '--directory', directory, '--repository', @remote, '--agent', 'claude',
                                '--with-rct', '--session-hook')
      refute_predicate process, :success?
      assert_includes output, "where Shaka keeps settings, not source. Found: #{canonical(directory)}. " \
                              "Next: #{fresh_command}"
      refute_path_exists directory
    end
  end

  # A folder the installer would create through a link to the settings folder is refused too.
  def test_a_missing_folder_behind_a_link_to_the_settings_path_is_refused
    FileUtils.mkdir_p(File.join(@home, '.agents'))
    File.symlink(File.join(@home, '.agents'), File.join(@home, 'alias'))
    output, process = install(@root, '--directory', File.join(@home, 'alias/new-source'), '--repository', @remote)
    refute_predicate process, :success?
    assert_includes output, 'where Shaka keeps settings'
    refute_path_exists File.join(@home, '.agents/new-source')
  end

  def test_an_install_at_the_old_default_refuses_every_action
    root = old_location_install('--agent', 'claude')
    [[], ['--update'], ['--verify']].each do |action|
      output, process = install(root, *action)
      refute_predicate process, :success?, action.inspect
      assert_includes output, "Next: #{take_over(root)}", action.inspect
    end
  end

  # The printed step must work: the hosts move to a fresh default checkout and the old one stays for the user.
  def test_the_printed_take_over_moves_every_link
    root = old_location_install('--agent', 'claude', '--with-rct')
    output, process = Open3.capture2e(environment, 'sh', '-c', take_over(root))
    assert_predicate process, :success?, output
    source = File.realpath(default_path)
    assert_location_summary(output, source, [File.join(@home, '.claude/skills')])
    assert_equal File.join(source, 'skills/rct'), File.realpath(File.join(@home, '.claude/skills/rct'))
    assert_path_exists File.join(root, 'skills/shaka')
  end

  # The old checkout's own installer finds the links it owns in a custom skills folder too.
  def test_the_take_over_moves_links_in_a_custom_skills_folder
    root = old_location_install('--skills-dir', @skills_dir)
    output, process = Open3.capture2e(environment, 'sh', '-c', take_over(root))
    assert_predicate process, :success?, output
    assert_equal File.join(File.realpath(default_path), 'skills/shaka'), File.realpath(@destination)
  end

  def test_an_update_names_where_everything_is
    root = clone_to(default_path)
    run_install(root, '--directory', root, '--repository', @remote, '--skills-dir', @skills_dir)
    commit(@root, 'updated skill')
    git('-C', @root, 'push', '-q', 'origin', 'main')
    output, process = install(root, '--update')
    assert_predicate process, :success?, output
    assert_location_summary(output, File.realpath(root), [File.expand_path(@skills_dir)])
  end

  private

  def fresh_command
    "#{Shellwords.escape(File.join(@root, 'bin/install'))} --directory #{Shellwords.escape(default_path)} " \
      "--repository #{Shellwords.escape(@remote)} --agent claude --with-rct --session-hook"
  end

  def install(root, *) = Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), *)

  def take_over(root)
    "#{Shellwords.escape(File.join(File.realpath(root), 'bin/install'))} --directory " \
      "#{Shellwords.escape(default_path)} --take-over"
  end
end

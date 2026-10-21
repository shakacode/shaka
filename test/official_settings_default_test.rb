# frozen_string_literal: true

require_relative 'install_scenario_support'

# A checkout under the settings path when the default location is already taken: an install registered
# there takes the links over itself, and anything else needs a person.
class OfficialSettingsDefaultTest < Minitest::Test
  include InstallScenarioSupport

  # A fresh default install alongside the old one takes over the links the old checkout still owns.
  def test_an_install_already_at_the_default_takes_the_links_over
    root = old_location_install('--agent', 'claude')
    run_install(clone_to(default_path), '--directory', default_path, '--repository', @remote, '--agent', 'codex')
    output, process = install(root)
    refute_predicate process, :success?
    step = "#{Shellwords.escape(File.join(default_path, 'bin/install'))} --take-over"
    assert_includes output, "Next: #{step}"
    run_step(step)
    assert_equal 'A5', status(default_path)['state']
  end

  # The default install cannot find the old checkout's links in a custom folder unless the step names it.
  def test_an_install_at_the_default_takes_over_a_custom_skills_folder
    root = old_location_install('--skills-dir', @skills_dir)
    run_install(clone_to(default_path), '--directory', default_path, '--repository', @remote, '--agent', 'codex')
    output, = install(root)
    step = output[/Next: (.+)$/, 1]
    assert_includes step, "--take-over --skills-dir #{Shellwords.escape(@skills_dir)}"
    run_step(step)
    assert_equal File.join(File.realpath(default_path), 'skills/shaka'), File.realpath(@destination)
  end

  def test_an_occupied_default_location_gets_a_decision
    root = old_location_install
    FileUtils.mkdir_p(File.join(default_path, 'leftover'))
    output, process = install(root)
    refute_predicate process, :success?
    assert_includes output, 'Next: a person must decide'
  end

  # The default install refuses to switch to the old checkout's origin, so a different one needs a person.
  def test_a_default_install_from_another_origin_gets_a_decision
    root = old_location_install('--agent', 'claude')
    other_origin_default_install
    output, process = install(root)
    refute_predicate process, :success?
    assert_includes output, 'Next: a person must decide'
    report = status(root)
    assert_equal 'E1', report['state']
    assert_nil report['next_command']
  end

  private

  def other_origin_default_install
    other = File.join(@directory, 'other.git')
    git('clone', '-q', '--bare', @remote, other)
    git('clone', '-q', other, default_path)
    run_install(default_path, '--directory', default_path, '--repository', other, '--agent', 'codex')
  end

  def run_step(step)
    output, process = Open3.capture2e(environment, 'sh', '-c', step)
    assert_predicate process, :success?, output
  end

  def install(root, *) = Open3.capture2e(environment, RbConfig.ruby, File.join(root, 'bin/install'), *)
end

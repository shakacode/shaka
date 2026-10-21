# frozen_string_literal: true

require_relative 'install_scenario_support'

# A source checkout that also hosts development gets the step that moves the hosts to a fresh checkout.
class InstallStatusDevelopmentTest < Minitest::Test
  include InstallScenarioSupport

  # Outside the default location, the installer's --take-over moves the hosts to a fresh checkout there.
  def test_development_elsewhere_names_the_take_over
    run_install(@root, '--directory', @root, '--repository', @remote)
    git('-C', @root, 'worktree', 'add', '-q', File.join(@directory, 'feature'))
    report = status(@root)
    assert_equal 'C3', report['state']
    assert_includes report['next_command'], "--directory #{Shellwords.escape(default_path)} --take-over"
  end

  def test_development_with_an_occupied_default_gets_a_decision
    run_install(@root, '--directory', @root, '--repository', @remote)
    git('-C', @root, 'worktree', 'add', '-q', File.join(@directory, 'feature'))
    FileUtils.mkdir_p(File.join(default_path, 'leftover'))
    report = status(@root)
    assert_equal 'C3', report['state']
    assert_nil report['next_command']
    assert_includes report['decision'], 'a person must decide'
  end

  def test_a_branch_with_unpushed_commits_is_development
    root = default_install
    git('-C', root, 'switch', '-q', '-c', 'experiment')
    commit(root, 'experiment')
    git('-C', root, 'switch', '-q', 'main')
    details = status(root)['findings'].map { |item| item['detail'] }
    assert(details.any? { |detail| detail.include?('local branches: experiment') }, details.inspect)
  end
end
